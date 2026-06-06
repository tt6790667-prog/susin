<?php
    /**
    * GET /api/orders - List all orders
    * POST /api/orders - Create new order
    */

    require_once __DIR__ . '/../../config/database.php';
    require_once __DIR__ . '/../../utils/jwt.php';
    require_once __DIR__ . '/../../utils/response.php';
    require_once __DIR__ . '/../../utils/permissions.php';
    require_once __DIR__ . '/../../utils/math_utils.php';
    require_once __DIR__ . '/prediction_utils.php';
    require_once __DIR__ . '/../../utils/auditLog.php';
    require_once __DIR__ . '/../../utils/email.php';

    set_time_limit(120);
    ini_set('memory_limit', '512M');

    // TEMPORARY DEBUG: Remove after fix
    set_error_handler(function($errno, $errstr, $errfile, $errline) {
        if (!(error_reporting() & $errno)) return; 
        header('Content-Type: application/json');
        if (!headers_sent()) http_response_code(500);
        echo json_encode(['error' => "PHP Error [$errno]: $errstr in " . basename($errfile) . ":$errline"]);
        exit;
    });
    register_shutdown_function(function() {
        $err = error_get_last();
        if ($err && in_array($err['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
            if (!headers_sent()) {
                header('Content-Type: application/json');
                http_response_code(500);
            }
            echo json_encode(['error' => 'Fatal: ' . $err['message'] . ' in ' . basename($err['file']) . ':' . $err['line']]);
        }
    });
    /**
     * MOVED function to avoid conflicting global execution
     */
    function ensureDashboardIndices(PDO $pdo) {
        $lockFile = __DIR__ . '/../dashboard/.perf_indices_applied_v6'; // v6: Added import_source for analytics
        // Wait, I should use a local lock for this file or sync with dashboard index lock.
        // Let's use a dedicated lock for orders API.
        $lockFile = __DIR__ . '/.perf_indices_applied_v3'; 
        if (file_exists($lockFile)) return;
        
        try {
            // COMPATIBLE SCHEMA UPGRADE: Indexing for Light Speed
            $pdo->exec("ALTER TABLE process_stages ADD INDEX IF NOT EXISTS idx_ps_order_stage (order_id, stage_key)");
            $pdo->exec("ALTER TABLE process_stages ADD INDEX IF NOT EXISTS idx_ps_stage_status_target (stage_key, status, target_end_time)");
            $pdo->exec("ALTER TABLE process_stages ADD INDEX IF NOT EXISTS idx_ps_order_id (order_id)");
            
            $pdo->exec("ALTER TABLE orders ADD INDEX IF NOT EXISTS idx_orders_location_date (location, order_booked_date)");
            $pdo->exec("ALTER TABLE orders ADD INDEX IF NOT EXISTS idx_orders_source (import_source)");
            $pdo->exec("ALTER TABLE orders ADD INDEX IF NOT EXISTS idx_orders_cat (product_category)");
            $pdo->exec("ALTER TABLE orders ADD INDEX IF NOT EXISTS idx_orders_so_no (sales_order_no)");
            
            @file_put_contents($lockFile, date('Y-m-d H:i:s'));
        } catch (Throwable $e) {
            // Fallback for older MySQL without 'IF NOT EXISTS' in ALTER
            try { $pdo->exec("CREATE INDEX idx_ps_order_stage ON process_stages(order_id, stage_key)"); } catch(Throwable $x){}
            try { $pdo->exec("CREATE INDEX idx_ps_stage_status_target ON process_stages(stage_key, status, target_end_time)"); } catch(Throwable $x){}
            try { $pdo->exec("CREATE INDEX idx_orders_location_date ON orders(location, order_booked_date)"); } catch(Throwable $x){}
            @file_put_contents($lockFile, date('Y-m-d H:i:s'));
        }
    }

    function ensureSchemaColumns(PDO $pdo) {
        $lockFile = __DIR__ . '/.orders_schema_applied_v28';
        if (file_exists($lockFile)) return;
        try {
            $columns = [
                'product_group' => "VARCHAR(255) DEFAULT NULL",
                'product_model' => "VARCHAR(255) DEFAULT NULL",
                'order_value_foreign' => "DECIMAL(15,2) DEFAULT 0.00",
                'sales_order_date' => "DATE DEFAULT NULL",
                'order_type' => "VARCHAR(100) DEFAULT NULL",
                'customer_po_date' => "DATE DEFAULT NULL",
                'product_description' => "TEXT DEFAULT NULL",
                'product_technical_details' => "TEXT DEFAULT NULL",
                'product_class' => "VARCHAR(100) DEFAULT NULL",
                'order_value_currency' => "VARCHAR(10) DEFAULT 'INR'",
                'stpl_wo_no' => "VARCHAR(100) DEFAULT NULL",
                'stpl_wo_date' => "DATE DEFAULT NULL",
                'siipl_wo_no' => "VARCHAR(100) DEFAULT NULL",
                'siipl_wo_date' => "DATE DEFAULT NULL",
                'remarks' => "TEXT DEFAULT NULL",
                'solution' => "TEXT DEFAULT NULL",
                'product_code' => "VARCHAR(100) DEFAULT NULL",
                'product_type' => "VARCHAR(100) DEFAULT NULL",
                'uom' => "VARCHAR(50) DEFAULT NULL",
                'rate' => "DECIMAL(15, 2) DEFAULT NULL",
                'currency' => "VARCHAR(20) DEFAULT 'INR'",
                'conversion_rate' => "DECIMAL(10, 4) DEFAULT 1.0",
                'customer_po_no' => "VARCHAR(255) DEFAULT NULL",
                'product_category' => "ENUM('Std', 'NPD', 'Customised', 'Automation') DEFAULT 'Std'",
                'sales_invoice_date' => "DATE DEFAULT NULL",
                'sales_invoice_no' => "VARCHAR(100) DEFAULT NULL",
                'is_planned' => "TINYINT(1) DEFAULT 1",
                'country' => "VARCHAR(100) DEFAULT NULL",
                'assigned_engineer' => "VARCHAR(36) DEFAULT NULL",
                'review_status' => "ENUM('WIP', 'COMPLETED', 'HOLD') DEFAULT 'WIP'",
                'design_completion_percentage' => "INT DEFAULT 0",
                'qc_completion_percentage' => "INT DEFAULT 0",
                'is_automation' => "TINYINT(1) DEFAULT 0",
                'dispatched_quantity' => "INT DEFAULT 0",
                'dispatched_value' => "DECIMAL(15, 2) DEFAULT 0.00",
                'region' => "VARCHAR(100) DEFAULT NULL"
            ];

            foreach ($columns as $column => $definition) {
                try {
                    $stmt = $pdo->prepare("SHOW COLUMNS FROM orders LIKE ?");
                    $stmt->execute([$column]);
                    $exists = $stmt->fetch();
                    
                    if (!$exists) {
                        $pdo->exec("ALTER TABLE orders ADD COLUMN $column $definition");
                    } else if ($column === 'product_category') {
                        // Special case: Ensure ENUM is up to date
                        $pdo->exec("ALTER TABLE orders MODIFY COLUMN product_category $definition");
                    }
                } catch (Throwable $e) {
                    error_log("Failed to sync column $column: " . $e->getMessage());
                }
            }

            // Sync 'region' column in users table
            try {
                $stmt = $pdo->prepare("SHOW COLUMNS FROM users LIKE 'region'");
                $stmt->execute();
                if (!$stmt->fetch()) {
                    $pdo->exec("ALTER TABLE users ADD COLUMN region VARCHAR(100) NULL AFTER designation");
                }
            } catch (Throwable $e) {}

            try {
                // FORCE FIX: Set all existing records as planned so they show in PMO Tracking
                $pdo->exec("UPDATE orders SET is_planned = 1 WHERE is_planned IS NULL OR is_planned = 0");

                // Sync product_category for existing orders based on current rules
                $pdo->exec("
                    UPDATE orders 
                    SET product_category = 'NPD' 
                    WHERE (product_category IS NULL OR product_category = 'Std') AND (LOWER(product_name) LIKE '%npd%' OR LOWER(product_group) LIKE '%npd%')
                ");
                $pdo->exec("
                    UPDATE orders 
                    SET product_category = 'Customised' 
                    WHERE (product_category IS NULL OR product_category = 'Std') AND (
                        LOWER(product_name) LIKE '%cus%' OR LOWER(product_name) LIKE '%customized%' OR 
                        LOWER(product_group) LIKE '%cus%' OR LOWER(product_group) LIKE '%customized%'
                    )
                ");
                $pdo->exec("
                    UPDATE orders 
                    SET product_category = 'Automation' 
                    WHERE (product_category IS NULL OR product_category = 'Std' OR product_category = '') AND (
                        LOWER(product_name) LIKE '%automation%' OR 
                        LOWER(product_group) LIKE '%automation%' OR 
                        LOWER(product_name) LIKE '%igd%' OR 
                        LOWER(product_group) LIKE '%igd%' OR 
                        LOWER(product_name) LIKE '%regulus%' OR
                        LOWER(product_group) LIKE '%regulus%'
                    )
                ");

                // DATA CORRECTION: Fix typos and standardise product_group to match Dashboard filters
                $pdo->exec("UPDATE orders SET product_group = 'ICD Series' WHERE LOWER(product_group) LIKE '%icd seires%' OR LOWER(product_group) LIKE '%icd series%'");
                $pdo->exec("UPDATE orders SET product_group = 'ISD Series' WHERE LOWER(product_group) LIKE '%isd seires%' OR LOWER(product_group) LIKE '%isd series%'");
                $pdo->exec("UPDATE orders SET product_group = 'ICR Series' WHERE LOWER(product_group) LIKE '%icr seires%' OR LOWER(product_group) LIKE '%icr series%'");
                $pdo->exec("UPDATE orders SET product_group = 'ISR Series' WHERE LOWER(product_group) LIKE '%isr seires%' OR LOWER(product_group) LIKE '%isr series%'");
                
                // Broaden mapping specifically for HD Actuators when product_group is empty or partial
                $pdo->exec("UPDATE orders SET product_group = 'ICD Series' WHERE LOWER(product_name) LIKE '%icd%' AND (product_group IS NULL OR product_group = '' OR LOWER(product_group) IN ('customised', 'automation', 'automation actuator', 'npd', 'spares'))");
                $pdo->exec("UPDATE orders SET product_group = 'ISD Series' WHERE LOWER(product_name) LIKE '%isd%' AND (product_group IS NULL OR product_group = '' OR LOWER(product_group) IN ('customised', 'automation', 'automation actuator', 'npd', 'spares'))");
                $pdo->exec("UPDATE orders SET product_group = 'ICR Series' WHERE LOWER(product_name) LIKE '%icr%' AND (product_group IS NULL OR product_group = '' OR LOWER(product_group) IN ('customised', 'automation', 'automation actuator', 'npd', 'spares'))");
                $pdo->exec("UPDATE orders SET product_group = 'ISR Series' WHERE LOWER(product_name) LIKE '%isr%' AND (product_group IS NULL OR product_group = '' OR LOWER(product_group) IN ('customised', 'automation', 'automation actuator', 'npd', 'spares'))");
            } catch (Throwable $e) {
                error_log("Data migration failed: " . $e->getMessage());
            }


            // Ensure additional tables
            $pdo->exec("CREATE TABLE IF NOT EXISTS order_comments (id CHAR(36) PRIMARY KEY, order_id CHAR(36), user_id CHAR(36), comment TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (order_id))");
            $pdo->exec("CREATE TABLE IF NOT EXISTS weekly_reviews (id CHAR(36) PRIMARY KEY, order_id CHAR(36) NOT NULL, week_code VARCHAR(20) NOT NULL, review_points TEXT, color_code VARCHAR(20) DEFAULT 'blue', commitment_week VARCHAR(20), remarks TEXT, updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX(order_id), UNIQUE(order_id, week_code)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;");

            // 4. AUTOMATIC DETECTION: Set is_automation to 1 if product fields contain 'AUTOMATION' or specific series/remarks
            try {
                $pdo->exec("UPDATE orders 
                           SET is_automation = 1 
                           WHERE (
                               LOWER(product_name) REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' OR 
                               LOWER(product_group) REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' OR
                               LOWER(product_model) REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' OR
                               LOWER(remarks) REGEXP 'accessories|automation|positioner|bare gad|bracket drg|bracket drawing'
                           )
                           AND (is_automation IS NULL OR is_automation = 0)");
                
                // 5. AUTOMATIC ASSIGNMENT: Append Gokul Prabhu's ID to those orders
                $gId = $pdo->query("SELECT id FROM users WHERE name LIKE '%GOKUL%PRABU%' LIMIT 1")->fetchColumn();
                if ($gId) {
                    $pdo->exec("UPDATE orders 
                               SET assigned_engineer = CASE 
                                   WHEN assigned_engineer IS NULL OR assigned_engineer = '' OR assigned_engineer = 'none' THEN '$gId'
                                   WHEN assigned_engineer NOT LIKE '%$gId%' THEN CONCAT(assigned_engineer, ', ', '$gId')
                                   ELSE assigned_engineer
                               END
                               WHERE is_automation = 1 
                               AND (assigned_engineer IS NULL OR assigned_engineer NOT LIKE '%$gId%')");
                }
            } catch (Throwable $e) {}

            @file_put_contents($lockFile, date('Y-m-d H:i:s'));
        } catch (Throwable $e) {}
    }

    /**
     * Ensure all valid status names exist in the lookup table
     */
    function ensureOrderStatusValues(PDO $pdo) {
        $lockFile = __DIR__ . '/.status_values_applied_v1';
        if (file_exists($lockFile)) return;
        try {
            $statuses = ['NA', 'STD', 'STOCK', 'PENDING', 'WIP', 'COMPLETED', 'DISPATCHED', 'SHIPPED', 'YTS', 'REVIEW', 'HOLD', 'R0 SUBMITTED', 'R1 SUBMITTED'];
            $stmt = $pdo->prepare("INSERT IGNORE INTO order_statuses (status_name) VALUES (?)");
            foreach ($statuses as $status) {
                $stmt->execute([$status]);
            }
            @file_put_contents($lockFile, date('Y-m-d H:i:s'));
        } catch (Throwable $e) {}
    }



    // allow including this file for testing without executing
    if (!defined('DO_NOT_RUN_WORKER')) {
        setCorsHeaders();
        
        $payload = requireAuth();
        $pdo = getDBConnection();
        
        // EMERGENCY DIAGNOSTIC
        if (isset($_GET['debug_db'])) {
            $total = $pdo->query("SELECT COUNT(*) FROM orders")->fetchColumn();
            $stages = $pdo->query("SELECT COUNT(*) FROM process_stages")->fetchColumn();
            $roles = $pdo->query("SELECT u.name, ur.role_name FROM users u JOIN user_roles ur ON u.id = ur.user_id")->fetchAll();
            jsonResponse([
                'db_order_count' => (int)$total,
                'db_stage_count' => (int)$stages,
                'user_roles' => $roles,
                'message' => 'Diagnostic mode enabled'
            ]);
            exit;
        }

        // SELF-HEALING: Wrap all schema ops — each silently continues on error
        try { ensureDashboardIndices($pdo); } catch (Throwable $e) { error_log("ensureDashboardIndices failed: " . $e->getMessage()); }
        try { ensureSchemaColumns($pdo); } catch (Throwable $e) { error_log("ensureSchemaColumns failed: " . $e->getMessage()); }
        try { ensureOrderStatusValues($pdo); } catch (Throwable $e) { error_log("ensureOrderStatusValues failed: " . $e->getMessage()); }
        
        try {
            if ($_SERVER['REQUEST_METHOD'] === 'GET') {
                if (isset($_GET['diag']) || isset($_GET['sync_all'])) {
                    handleDebugAndSync($pdo, $payload);
                    exit;
                }
                handleGetOrders($pdo, $payload, $_GET);
            } elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
                handleCreateOrder($pdo, $payload, getJsonBody());
            } elseif ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
                handleDeleteOrder($pdo, $payload, getJsonBody());
            } else {
                errorResponse('Method not allowed', 405);
            }
        } catch (Throwable $e) {
            errorResponse('Top-level error: ' . $e->getMessage() . ' in ' . basename($e->getFile()) . ':' . $e->getLine(), 500);
        }
    }

    /**
    * Get monthly capacity from system_configs
    */
    function getMonthlyCapacity(PDO $pdo): float {
        try {
            $stmt = $pdo->prepare("SELECT config_value FROM system_configs WHERE config_key = 'monthly_capacity' LIMIT 1");
            $stmt->execute();
            $val = $stmt->fetch(PDO::FETCH_ASSOC);
            return $val && isset($val['config_value']) ? (float)$val['config_value'] : 30000000.0;
        } catch (Throwable $e) {
            // Self-Healing: If table doesn't exist, create it and seed default
            try {
                if (strpos($e->getMessage(), "doesn't exist") !== false) {
                    $pdo->exec("
                        CREATE TABLE IF NOT EXISTS system_configs (
                            config_key VARCHAR(50) PRIMARY KEY,
                            config_value TEXT,
                            description TEXT,
                            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                            updated_by VARCHAR(36)
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                    ");
                    $pdo->exec("INSERT IGNORE INTO system_configs (config_key, config_value) VALUES ('monthly_capacity', '30000000')");
                    return 30000000.0;
                }
            } catch (Throwable $ex) {
                // Ignore nested errors
            }
            return 30000000.0;
        }
    }

    /**
    * Get total value of orders booked/active in the current calendar month
    * Changed from 'dispatch' status to 'booking' status per user request (Total Value of 13k+)
    */
    function getMonthlyActualOutcome(PDO $pdo): float {
        try {
            $stmt = $pdo->prepare("
                SELECT SUM(order_value) as total
                FROM orders
                WHERE MONTH(order_booked_date) = MONTH(CURRENT_DATE())
                AND YEAR(order_booked_date) = YEAR(CURRENT_DATE())
            ");
            $stmt->execute();
            $result = $stmt->fetch(PDO::FETCH_ASSOC);
            return $result && isset($result['total']) ? (float)$result['total'] : 0.0;
        } catch (Throwable $e) {
            return 0.0;
        }
    }


    /**
    * Get SQL condition for Purchase filters based on user name
    */
    function getPurchaseFilterConditions(string $name): string {
        /* 
        MAPPING:
        - Pavithiran & Vignesh: RM Purchase (General), Packing Materials (Vignesh)
        - Saravana Murugavel: BO Purchase (O-rings, Fasteners), Springs
        - Prabakar: RM Casting, Cylinder Purchase
        */

        // FIXED: Strict row filtering hidden all orders because product data might not match keywords exactly.
        // Strategy: Show ALL orders (1=1) to ensure visibility.
        // The "Focus" is handled by the Frontend Column Filtering (Columns are hidden/shown).
        // This allows them to see the full list but only act on their columns.
        return "1=1";

        /* -- PREVIOUS STRICT LOGIC (Keep for reference if data is cleaned up) --
        // Prabakar -> Cylinder Purchase OR Casting
        if (strpos($name, 'prabakar') !== false) {
            return "
                (o.product_group LIKE '%Cylinder%' OR o.product_group LIKE '%Pneumatic%') 
                OR 
                (
                    o.product_name LIKE '%Casting%' OR 
                    o.product_description LIKE '%Casting%' OR
                    o.product_type LIKE '%Casting%'
                )
            ";
        }
        ...
        */
    }

    /**
    * Handle Diagnostics and Sync (Embedded to bypass 404 errors)
    */
    function handleDebugAndSync(PDO $pdo, array $payload): void {
        header('Content-Type: application/json');
        $results = ['timestamp' => date('Y-m-d H:i:s')];
        
        if (isset($_GET['sync_all'])) {
            try {
                $pdo->beginTransaction();
                $stmt = $pdo->query("SELECT id FROM orders");
                $allDocIds = $stmt->fetchAll(PDO::FETCH_COLUMN);
                $workflowStages = ['planningOrder', 'gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'automationDrawing', 'erpBomActuator', 'erpBomAutomation', 'storesStockVerification', 'rawMaterialPurchase', 'cylinderPurchase', 'springPurchase', 'productionMachining', 'boughtOutPartsPurchase', 'automationPartsPurchase', 'assemblyActuator', 'painting', 'finalAssembly', 'quality', 'dispatch'];
                $created = 0;
                foreach ($allDocIds as $oid) {
                    $orderStmt = $pdo->prepare("SELECT product_name, product_group, is_automation FROM orders WHERE id = ?");
                    $orderStmt->execute([$oid]);
                    $order = $orderStmt->fetch(PDO::FETCH_ASSOC);
                    
                    $isAuto = (int)($order['is_automation'] ?? 0);
                    if (!$isAuto) {
                        $combined = strtoupper(($order['product_name'] ?? '') . ' ' . ($order['product_group'] ?? ''));
                        if (strpos($combined, 'AUTOMATION') !== false) $isAuto = 1;
                    }
                    
                    $automationKeys = ['automationDrawing', 'erpBomAutomation', 'automationPartsPurchase'];
                    $engineeringNonAutomationKeys = ['gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'erpBomActuator'];

                    foreach ($workflowStages as $sk) {
                        $status = 'PENDING';
                        if (!$isAuto && in_array($sk, $automationKeys)) {
                            $status = 'NA';
                        } else if ($isAuto && in_array($sk, $engineeringNonAutomationKeys)) {
                            $status = 'NA';
                        }

                        $check = $pdo->prepare("SELECT status FROM process_stages WHERE order_id = ? AND stage_key = ?");
                        $check->execute([$oid, $sk]);
                        $existing = $check->fetch();
                        
                        if (!$existing) {
                            $ins = $pdo->prepare("INSERT INTO process_stages (order_id, stage_key, status, locked) VALUES (?, ?, ?, 1)");
                            $ins->execute([$oid, $sk, $status]);
                            $created++;
                        } else {
                            if (!$isAuto && in_array($sk, $automationKeys)) {
                                // Only reset default placeholders — preserve manual workflow updates (WIP, COMPLETED, etc.)
                                $upd = $pdo->prepare("UPDATE process_stages SET status = 'NA' WHERE order_id = ? AND stage_key = ? AND status IN ('PENDING', 'REVIEW', 'YTS')");
                                $upd->execute([$oid, $sk]);
                            } else if ($isAuto && in_array($sk, $automationKeys)) {
                                $upd = $pdo->prepare("UPDATE process_stages SET status = 'PENDING' WHERE order_id = ? AND stage_key = ? AND status = 'NA'");
                                $upd->execute([$oid, $sk]);
                            }

                            if ($isAuto && in_array($sk, $engineeringNonAutomationKeys)) {
                                $upd = $pdo->prepare("UPDATE process_stages SET status = 'NA' WHERE order_id = ? AND stage_key = ? AND status IN ('PENDING', 'REVIEW', 'YTS')");
                                $upd->execute([$oid, $sk]);
                            } else if (!$isAuto && in_array($sk, $engineeringNonAutomationKeys)) {
                                $upd = $pdo->prepare("UPDATE process_stages SET status = 'PENDING' WHERE order_id = ? AND stage_key = ? AND status = 'NA'");
                                $upd->execute([$oid, $sk]);
                            }
                        }
                    }
                }
                $pdo->commit();
                $results['sync'] = "SUCCESS: $created stages created.";
            } catch (Exception $e) {
                $pdo->rollBack();
                $results['sync_error'] = $e->getMessage();
            }
        }

        if (isset($_GET['diag'])) {
            $userId = $payload['user_id'];
            $roleInfo = strtolower($payload['role'] ?? '');
            $results['diag_user'] = ['id' => $userId, 'role' => $roleInfo];
            
            // Check assignments
            $stmt = $pdo->prepare("SELECT product_name FROM user_product_assignments WHERE user_id = ?");
            $stmt->execute([$userId]);
            $assigns = $stmt->fetchAll(PDO::FETCH_COLUMN);
            $results['assignments'] = $assigns;

            // Trace SQL Logic
            $conditions = ["1=1"];
            $params = [];
            if (!empty($assigns)) {
                $results['diag_mode'] = "PRODUCT_RESTRICTED";
                $pConds = [];
                foreach ($assigns as $p) {
                    // Use the same logic as handleGetOrders
                    $pConds[] = "(LOWER(o.product_name) LIKE LOWER(?) OR LOWER(o.product_group) LIKE LOWER(?) OR LOWER(o.product_code) LIKE LOWER(?) OR LOWER(o.product_model) LIKE LOWER(?) OR LOWER(o.product_type) LIKE LOWER(?))";
                    $term = "%".trim($p)."%";
                    $params = array_merge($params, array_fill(0, 5, $term));
                }
                $conditions[] = "(" . implode(" OR ", $pConds) . ")";
            }
            
            $results['potential_query'] = "SELECT id, product_name FROM orders o WHERE " . implode(" AND ", $conditions);
            $results['params'] = $params;

            // Test run
            try {
                $test = $pdo->prepare($results['potential_query'] . " LIMIT 5");
                $test->execute($params);
                $results['sample_results'] = $test->fetchAll();
                $results['match_count'] = count($results['sample_results']);
            } catch (Exception $e) {
                $results['query_error'] = $e->getMessage();
            }
        }

        echo json_encode($results, JSON_PRETTY_PRINT);
    }

    function handleGetOrders(PDO $pdo, array $payload, array $queryParams): void {
        // EMERGENCY FORCE: Ensure the column exists before any query
        try {
            $pdo->exec("ALTER TABLE orders ADD COLUMN is_automation TINYINT(1) DEFAULT 0");
        } catch (Throwable $e) {
            // Silence column exists errors
        }

        // Get query parameters
        $location = $queryParams['location'] ?? null;
        // Normalize location: uppercase + fix SIIPI->SIIPL typo
        if ($location) {
            $location = strtoupper(trim($location));
            if ($location === 'SIIPI') $location = 'SIIPL';
            if ($location === 'ALL') $location = null; // ALL means no filter
        }
        $region = $queryParams['region'] ?? null;
        $status = $queryParams['status'] ?? null;
        $search = $queryParams['search'] ?? null;
        $date_from = $queryParams['date_from'] ?? null;
        $date_to = $queryParams['date_to'] ?? null;
        $edd_from = $queryParams['edd_from'] ?? null;
        $edd_to = $queryParams['edd_to'] ?? null;
        $page = max(1, (int)($queryParams['page'] ?? 1));
        $limit = min(5000, max(1, (int)($queryParams['limit'] ?? 50)));
        $offset = ($page - 1) * $limit;
        
        $roleInfo = strtolower(trim(str_replace(' ', '_', $payload['role'] ?? '')));

        // ── Cross-Domain Region Resolution ────────────────────────────────────
        // Central DB (centralusers.susingroup.com) stores region.
        // Orders DB (gm.susingroup.com) is a separate DB — region is NOT synced.
        // Solution: Call Central API via HTTP using the same Bearer token.
        $userRegion      = '';
        $userDesignation = strtolower(trim($payload['designation'] ?? $payload['role'] ?? ''));
        $userEmail       = $payload['email'] ?? $payload['user']['email'] ?? '';

        // ── Step 1: Determine role first (skip HTTP call for global admin roles) ─
        $isGlobalAdmin = in_array($roleInfo, ['admin', 'gm', 'planner', 'planning', 'planning_head', 'management'], true)
                      || in_array($userDesignation, ['admin', 'administrator', 'gm'], true);

        if (!$isGlobalAdmin) {
            // ── Step 2: Call Central API to get region ─────────────────────────
            $centralRegionFetched = false;
            $authHeader = $_SERVER['HTTP_AUTHORIZATION'] ?? 
                          (function_exists('getallheaders') ? (getallheaders()['Authorization'] ?? getallheaders()['authorization'] ?? '') : '');

            if (!empty($authHeader)) {
                try {
                    $ctx = stream_context_create([
                        'http' => [
                            'method'  => 'GET',
                            'header'  => "Authorization: $authHeader\r\nAccept: application/json\r\n",
                            'timeout' => 3, // 3 second timeout — fast fail
                            'ignore_errors' => true,
                        ]
                    ]);
                    $centralUrl      = 'https://centralusers.susingroup.com/backend-php/api/auth/get_user_region.php';
                    $centralResponse = @file_get_contents($centralUrl, false, $ctx);
                    if ($centralResponse !== false) {
                        $centralData = json_decode($centralResponse, true);
                        if (isset($centralData['success']) && $centralData['success']) {
                            $userRegion      = trim($centralData['region'] ?? '');
                            $userDesignation = strtolower(trim($centralData['designation'] ?? $userDesignation));
                            $centralRegionFetched = true;
                        }
                    }
                } catch (Throwable $e) {
                    // Central API call failed — fall through to local DB fallback
                }
            }

            // ── Step 3: Fallback — check local Orders DB (in case region was synced) ─
            if (!$centralRegionFetched && !empty($userEmail)) {
                try {
                    $userStmt = $pdo->prepare("SELECT designation, region FROM users WHERE email = ? LIMIT 1");
                    $userStmt->execute([$userEmail]);
                    $userDb = $userStmt->fetch();
                    if ($userDb) {
                        if (empty($userRegion)) {
                            $userRegion = trim($userDb['region'] ?? '');
                        }
                        if ($userDesignation === $roleInfo) {
                            $userDesignation = strtolower(trim($userDb['designation'] ?? $userDesignation));
                        }
                    }
                } catch (Throwable $e) {}
            }

            // ── Step 4: Re-check isGlobalAdmin with resolved designation ─────────
            $isGlobalAdmin = in_array($roleInfo, ['admin', 'gm', 'planner', 'planning', 'planning_head', 'management'], true)
                          || in_array($userDesignation, ['admin', 'administrator', 'gm'], true);
        }

        // ── Force region filter for non-admin users with assigned region ──────
        if (!$isGlobalAdmin && !empty($userRegion)) {
            $region = $userRegion;
        } else {
            // GM / Admin — no region restriction, clear userRegion for frontend
            $userRegion = '';
        }

        try {
            // Build WHERE clause
            $conditions = [];
            $params = [];
            
            require_once __DIR__ . '/../../utils/portal_helper.php';
            applyGearFilterIfRequired($conditions);
            
            // $location is already null if 'ALL' was selected (normalized above)
            if ($location) {
                $conditions[] = "o.location = ?";
                $params[] = $location;
            }

            $regionLower = $region ? strtolower(trim($region)) : '';
            if ($regionLower && $regionLower !== 'all' && $regionLower !== 'all regions' && $regionLower !== 'all_regions') {
                $baseRegion = trim(str_ireplace('team', '', $region));
                $baseRegion = rtrim($baseRegion, 's'); // Remove trailing 's' to handle singular/plural
                
                // Compatibility for UAE/Middle East name change
                if (strtoupper($region) === 'UAE') {
                    $conditions[] = "(o.region = ? OR o.region LIKE ? OR o.region LIKE ? OR o.region = 'Middle East' OR o.region LIKE '%Middle East%')";
                } else {
                    $conditions[] = "(o.region = ? OR o.region LIKE ? OR o.region LIKE ?)";
                }
                
                $params[] = $region;
                $params[] = "%" . $baseRegion . "%";
                $params[] = "%" . $baseRegion . "s%"; 
            }
            
            if ($search) {
                if (strpos($search, ' - ') !== false) {
                    $parts = explode(' - ', $search);
                    $firstPart = trim($parts[0]);
                    $lastPart = trim(end($parts));
                    $conditions[] = "(o.product_code LIKE ? OR o.product_name LIKE ? OR o.sales_order_no LIKE ? OR o.customer_name LIKE ?)";
                    $params[] = "%$firstPart%";
                    $params[] = "%$lastPart%";
                    $params[] = "%$search%";
                    $params[] = "%$search%";
                } else {
                    $conditions[] = "(o.sales_order_no LIKE ? OR o.customer_name LIKE ? OR o.product_name LIKE ? OR o.product_model LIKE ? OR o.product_group LIKE ? OR o.line_item_id LIKE ? OR o.project_end_customer LIKE ? OR o.product_code LIKE ?)";
                    $searchTerm = "%$search%";
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                    $params[] = $searchTerm;
                }
            }
            
            if ($date_from) {
                $conditions[] = "o.sales_order_date >= ?";
                $params[] = $date_from;
            }
            if ($date_to) {
                $conditions[] = "o.sales_order_date <= ?";
                $params[] = $date_to;
            }
            
            if ($edd_from) {
                $conditions[] = "o.expected_delivery_date >= ?";
                $params[] = $edd_from;
            }
            if ($edd_to) {
                $conditions[] = "o.expected_delivery_date <= ?";
                $params[] = $edd_to;
            }

            $productParam = $queryParams['product'] ?? null;
            if ($productParam && $productParam !== 'all') {
                $conditions[] = "o.product_group = ?";
                $params[] = $productParam;
            }

            $modelParam = $queryParams['model'] ?? null;
            if ($modelParam && $modelParam !== 'all') {
                $conditions[] = "(o.product_model = ? OR o.product_name LIKE ? OR o.product_code = ?)";
                $params[] = $modelParam;
                $params[] = "%" . $modelParam . "%";
                $params[] = $modelParam;
            }

            if ($status && strtolower($status) !== 'all') {
                $statusUpper = strtoupper($status);
                
                // Roles that should see the GLOBAL status (completion = dispatched)
                $isManagementRole = in_array($roleInfo, ['admin', 'gm', 'planner', 'planning', 'planning_head', 'management']);
                $specificDept = $queryParams['dept'] ?? null;

                if (($statusUpper === 'COMPLETED' || $statusUpper === 'DISPATCHED') && $isManagementRole && (!$specificDept || $specificDept === 'all')) {
                    // For Management, "Completed" means the entire order is Dispatched (Global)
                    $conditions[] = "EXISTS (SELECT 1 FROM process_stages WHERE order_id = o.id AND stage_key = 'dispatch' AND status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED'))";
                } else if ($statusUpper === 'PENDING' && $isManagementRole && (!$specificDept || $specificDept === 'all')) {
                    // For Management, "Pending" means not yet Dispatched (Global)
                    $conditions[] = "NOT EXISTS (SELECT 1 FROM process_stages WHERE order_id = o.id AND stage_key = 'dispatch' AND status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED'))";
                } else if ($statusUpper === 'COMPLETED' || $statusUpper === 'PENDING') {
                    // DEPARTMENT COMPLETED/PENDING LOGIC (SQL side)
                    $deptStages = [];
                    // Check either role or explicit dept parameter
                    if ($roleInfo === 'machining_head') {
                        $deptStages = ['productionMachining', 'assemblyActuator', 'painting', 'finalAssembly', 'packing', 'dispatch'];
                    } else if ($roleInfo === 'assembly_head') {
                        $deptStages = ['assemblyActuator', 'painting', 'finalAssembly', 'packing', 'dispatch'];
                    } else if ($specificDept === 'engineering' || strpos($roleInfo, 'engineering') !== false || strpos($roleInfo, 'design') !== false) {
                        $deptStages = ['gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'erpBomActuator'];
                    } else if ($specificDept === 'regulus') {
                        $deptStages = ['gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'erpBomActuator', 'automationDrawing', 'erpBomAutomation'];
                        $conditions[] = "(o.is_automation = 1 OR o.assigned_engineer LIKE '%gokul%' OR o.product_name LIKE '%PD%' OR o.product_name LIKE '%PS%' OR o.product_group LIKE '%PD%' OR o.product_group LIKE '%PS%')";
                    } else if ($specificDept === 'stores' || strpos($roleInfo, 'stores') !== false) {
                        $deptStages = ['storesStockVerification'];
                    } else if ($specificDept === 'purchase' || strpos($roleInfo, 'purchase') !== false) {
                        $deptStages = ['rawMaterialPurchase', 'cylinderPurchase', 'springPurchase', 'boughtOutPartsPurchase', 'automationPartsPurchase'];
                    } else if ($specificDept === 'machining' || strpos($roleInfo, 'machining') !== false) {
                        $deptStages = ['productionMachining'];
                    } else if ($specificDept === 'assembly' || strpos($roleInfo, 'assembly') !== false) {
                        $deptStages = ['assemblyActuator', 'finalAssembly'];
                    } else if ($specificDept === 'painting' || strpos($roleInfo, 'painting') !== false) {
                        $deptStages = ['painting'];
                    } else if ($specificDept === 'quality' || strpos($roleInfo, 'quality') !== false) {
                        $deptStages = ['inwardQC', 'inlineQC', 'finalQC', 'documentationQC'];
                    } else if ($specificDept === 'dispatch' || strpos($roleInfo, 'dispatch') !== false) {
                        $deptStages = ['packing', 'dispatch'];
                    }

                    if (!empty($deptStages)) {
                        $placeholders = implode(',', array_fill(0, count($deptStages), '?'));
                        
                        if ($statusUpper === 'COMPLETED') {
                            // Must have at least one stage reached AND no stages should be pending
                            $conditions[] = "EXISTS (
                                SELECT 1 FROM process_stages ps_ex
                                WHERE ps_ex.order_id = o.id 
                                AND ps_ex.stage_key IN ($placeholders)
                                AND ps_ex.status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED', 'NA')
                                AND (
                                    1=1
                                )
                            ) AND NOT EXISTS (
                                SELECT 1 FROM process_stages ps_not
                                WHERE ps_not.order_id = o.id 
                                AND ps_not.stage_key IN ($placeholders) 
                                AND ps_not.status NOT IN ('COMPLETED', 'DISPATCHED', 'SHIPPED', 'NA')
                                AND (
                                    1=1
                                )
                            )";
                        } else {
                            // PENDING: At least one dept stage is in PENDING/WIP/YTS/REVIEW/PARTIAL state
                            // OR if no stages exist yet for this department but the order is assigned to the current user
                            $conditions[] = "(
                                EXISTS (
                                    SELECT 1 FROM process_stages ps_p
                                    WHERE ps_p.order_id = o.id 
                                    AND ps_p.stage_key IN ($placeholders) 
                                    AND ps_p.status IN ('PENDING', 'WIP', 'YTS', 'REVIEW', 'PARTIAL')
                                )
                                OR (
                                    (o.assigned_engineer = ? OR o.assigned_engineer LIKE ? OR o.assigned_engineer LIKE ? OR o.assigned_engineer LIKE ?)
                                    AND NOT EXISTS (
                                        SELECT 1 FROM process_stages ps_any
                                        WHERE ps_any.order_id = o.id 
                                        AND ps_any.stage_key IN ($placeholders)
                                    )
                                )
                            )";
                        }
                        if ($statusUpper === 'COMPLETED') {
                            $params = array_merge($params, $deptStages, $deptStages);
                        } else {
                            $params = array_merge(
                                $params, 
                                $deptStages, 
                                [
                                    $payload['user_id'], 
                                    "%," . $payload['user_id'] . "%", 
                                    $payload['user_id'] . ",%", 
                                    "%," . $payload['user_id'] . ",%"
                                ],
                                $deptStages
                            );
                        }
                    } else {
                        // FALLBACK FOR NON-DEPT ROLES (e.g. Sales, Accounts, Production Head etc.)
                        // Treat "Completed" as Dispatched, and "Pending" as not yet Dispatched.
                        if ($statusUpper === 'COMPLETED') {
                            $conditions[] = "EXISTS (SELECT 1 FROM process_stages WHERE order_id = o.id AND stage_key = 'dispatch' AND status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED'))";
                        } else {
                            $conditions[] = "NOT EXISTS (SELECT 1 FROM process_stages WHERE order_id = o.id AND stage_key = 'dispatch' AND status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED'))";
                        }
                    }
                } else if ($statusUpper === 'DELAYED') {
                    // Match Dashboard definition: (NOT DISPATCHED) AND (Overall EDD Overdue OR Any stage is Overdue/Late)
                    $conditions[] = "
                        NOT EXISTS (SELECT 1 FROM process_stages ps_fin WHERE ps_fin.order_id = o.id AND ps_fin.stage_key = 'dispatch' AND ps_fin.status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED'))
                        AND (
                            (o.expected_delivery_date IS NOT NULL AND o.expected_delivery_date != '0000-00-00' AND o.expected_delivery_date < CURRENT_DATE)
                            OR EXISTS (
                                SELECT 1 FROM process_stages ps_d 
                                WHERE ps_d.order_id = o.id 
                                AND ps_d.status != 'NA'
                                AND (
                                    -- Case A: Still pending and past target
                                    (ps_d.status NOT IN ('COMPLETED', 'DISPATCHED', 'SHIPPED') AND ps_d.target_end_time IS NOT NULL AND ps_d.target_end_time != '0000-00-00 00:00:00' AND ps_d.target_end_time < NOW())
                                    -- Case B: Finished but was late (and order isn't fully dispatched yet)
                                    OR (ps_d.status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED') AND ps_d.actual_end_time > ps_d.target_end_time)
                                    -- Case C: Planning pending for more than 1 day
                                    OR (ps_d.stage_key = 'planningOrder' AND ps_d.status NOT IN ('COMPLETED', 'DISPATCHED', 'SHIPPED') AND DATEDIFF(NOW(), o.order_booked_date) >= 1)
                                )
                            )
                        )
                    ";
                } else if ($statusUpper === 'ON_TIME') {
                    // On-Time: (Not Dispatched & Future EDD) OR (Dispatched & Finished Early/OnTime)
                    $conditions[] = "
                        (
                            (NOT EXISTS (SELECT 1 FROM process_stages ps WHERE ps.order_id = o.id AND ps.stage_key = 'dispatch' AND ps.status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED')) 
                            AND o.expected_delivery_date >= CURRENT_DATE)
                            OR 
                            (EXISTS (SELECT 1 FROM process_stages ps WHERE ps.order_id = o.id AND ps.stage_key = 'dispatch' AND ps.status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED') AND ps.actual_end_time <= o.expected_delivery_date))
                        )
                    ";
                } else if (!in_array($statusUpper, ['COMPLETED', 'DISPATCHED', 'PENDING'])) {
                    // For specific individual statuses (WIP, HOLD, etc.), we keep the generic check
                    $conditions[] = "EXISTS (SELECT 1 FROM process_stages WHERE order_id = o.id AND status = ?)";
                    $params[] = $statusUpper;
                }
                // For COMPLETED/PENDING with Dept roles, we skip backend filter 
                // so the frontend hook can do its flexible per-stage logic.
            }

            // Filter by Order Type (Matches Dashboard logic)
            $type = $queryParams['type'] ?? null;
            if ($type === 'customized') {
                $conditions[] = "
                    (LOWER(o.product_name) LIKE '%cus%' OR LOWER(o.product_name) LIKE '%customized%' OR LOWER(o.product_group) LIKE '%cus%' OR LOWER(o.product_group) LIKE '%customized%') 
                    AND (LOWER(o.product_name) NOT LIKE '%npd%' AND LOWER(o.product_group) NOT LIKE '%npd%')
                    AND (LOWER(o.product_name) NOT LIKE '%automation%' AND LOWER(o.product_group) NOT LIKE '%automation%' AND LOWER(o.product_name) NOT LIKE '%regulus%' AND LOWER(o.product_group) NOT LIKE '%regulus%' AND LOWER(o.product_name) NOT LIKE '%igd%' AND LOWER(o.product_group) NOT LIKE '%igd%')
                ";
            } else if ($type === 'npd') {
                $conditions[] = "(LOWER(o.product_name) LIKE '%npd%' OR LOWER(o.product_group) LIKE '%npd%')";
            } else if ($type === 'automation') {
                $conditions[] = "(LOWER(o.product_name) LIKE '%automation%' OR LOWER(o.product_group) LIKE '%automation%' OR LOWER(o.product_name) LIKE '%regulus%' OR LOWER(o.product_group) LIKE '%regulus%' OR LOWER(o.product_name) LIKE '%igd%' OR LOWER(o.product_group) LIKE '%igd%')";
            } else if ($type === 'spare') {
                $conditions[] = "(LOWER(o.product_name) LIKE '%spare%' OR LOWER(o.product_group) LIKE '%spare%')";
            } else if ($type === 'standard') {
                $conditions[] = "
                    (LOWER(o.product_name) NOT LIKE '%cus%' AND LOWER(o.product_name) NOT LIKE '%customized%' AND LOWER(o.product_group) NOT LIKE '%cus%' AND LOWER(o.product_group) NOT LIKE '%customized%') 
                    AND (LOWER(o.product_name) NOT LIKE '%npd%' AND LOWER(o.product_group) NOT LIKE '%npd%')
                    AND (LOWER(o.product_name) NOT LIKE '%automation%' AND LOWER(o.product_group) NOT LIKE '%automation%' AND LOWER(o.product_name) NOT LIKE '%regulus%' AND LOWER(o.product_group) NOT LIKE '%regulus%' AND LOWER(o.product_name) NOT LIKE '%igd%' AND LOWER(o.product_group) NOT LIKE '%igd%')
                    AND (LOWER(o.product_name) NOT LIKE '%spare%' AND LOWER(o.product_group) NOT LIKE '%spare%')
                ";
            }

            // Department-wise Filtering (for Drill-down)
            $deptParam = $queryParams['dept'] ?? null;
            if ($deptParam && $deptParam !== 'all') {
                $deptStages = [];
                switch(strtolower($deptParam)) {
                    case 'engineering':
                        $deptStages = ['gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'erpBomActuator'];
                        break;
                    case 'regulus':
                        $deptStages = ['gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'erpBomActuator', 'automationDrawing', 'erpBomAutomation'];
                        $conditions[] = "(o.is_automation = 1 OR o.assigned_engineer LIKE '%gokul%' OR o.product_name LIKE '%PD%' OR o.product_name LIKE '%PS%' OR o.product_group LIKE '%PD%' OR o.product_group LIKE '%PS%')";
                        break;
                    case 'customer gad approval':
                    case 'customer gadgets': // fuzzy match safety
                    case 'customer_gad_approval':
                        $deptStages = ['customerGadApproval'];
                        break;
                    case 'purchase':
                        $deptStages = ['storesStockVerification', 'rawMaterialPurchase', 'cylinderPurchase', 'springPurchase', 'boughtOutPartsPurchase'];
                        break;
                    case 'automation purchase':
                    case 'automation_purchase':
                        $deptStages = ['automationPartsPurchase'];
                        break;
                    case 'machining':
                    case 'production':
                        $deptStages = ['productionMachining'];
                        break;
                    case 'assembly':
                        $deptStages = ['assemblyActuator', 'finalAssembly'];
                        break;
                    case 'quality':
                        $deptStages = ['quality'];
                        break;
                    case 'painting':
                        $deptStages = ['painting'];
                        break;
                    case 'planning':
                        $deptStages = ['planningOrder'];
                        break;
                    case 'dispatch':
                        $deptStages = ['dispatch'];
                        break;
                }

                // Modification: Bypass department exists check if search is active OR if it's a head role searching for their dept
                $searchTermActive = !empty($queryParams['search']);
                $isHeadRole = (strpos($roleInfo, '_head') !== false) || (strpos($roleInfo, 'reviewer') !== false) || in_array($roleInfo, ['admin', 'gm', 'planner', 'planning', 'management']);
                
                // Allow "NA" stages to be visible if: 
                // 1. Searching (Global search)
                // 2. Head Role (Visibility over everything in dept)
                // 3. Status filter is explicitly set to ALL or NA or COMPLETED
                $statusFilter = strtolower($queryParams['status'] ?? 'all');
                $includeNA = ($statusFilter === 'all' || $statusFilter === 'na' || $statusFilter === 'completed' || $isHeadRole);

                if (!empty($deptStages) && !$searchTermActive) {
                    $placeholders = implode(',', array_fill(0, count($deptStages), '?'));
                    $statusCondition = $includeNA ? "" : "AND ps_dept.status != 'NA'";

                    if (isset($queryParams['status']) && strtolower($queryParams['status']) === 'delayed') {
                        $delayBucket = $queryParams['delay_bucket'] ?? null;
                        if ($delayBucket && $delayBucket !== 'all') {
                            // Bypassed Root Cause logic when a specific color card is clicked
                            $conditions[] = "EXISTS (
                                SELECT 1 FROM process_stages ps_dept 
                                WHERE ps_dept.order_id = o.id 
                                AND ps_dept.stage_key IN ($placeholders)
                                AND ps_dept.status NOT IN ('COMPLETED', 'DISPATCHED', 'SHIPPED', 'NA')
                                AND (
                                    (ps_dept.target_end_time IS NOT NULL AND ps_dept.target_end_time != '0000-00-00 00:00:00' AND ps_dept.target_end_time < NOW())
                                    OR (ps_dept.stage_key = 'planningOrder' AND DATEDIFF(NOW(), o.order_booked_date) >= 1)
                                )
                            )";
                        } else {
                            // ROOT CAUSE LOGIC: Only show in this department if it is the FIRST department causing a delay
                            $stageField = "'planningOrder', 'gadSubmission', 'customerGadApproval', 'manufacturingDrawingBom', 'automationDrawing', 'erpBomActuator', 'erpBomAutomation', 'storesStockVerification', 'rawMaterialPurchase', 'cylinderPurchase', 'springPurchase', 'boughtOutPartsPurchase', 'automationPartsPurchase', 'productionMachining', 'assemblyActuator', 'painting', 'finalAssembly', 'quality', 'dispatch'";
                            
                            $conditions[] = "EXISTS (
                                SELECT 1 FROM process_stages ps_dept 
                                WHERE ps_dept.order_id = o.id 
                                AND ps_dept.stage_key IN ($placeholders)
                                -- It must be the EARLIEST delayed stage
                                AND FIELD(ps_dept.stage_key, $stageField) = (
                                    SELECT MIN(FIELD(ps_any.stage_key, $stageField))
                                    FROM process_stages ps_any
                                    WHERE ps_any.order_id = o.id
                                    AND ps_any.status NOT IN ('COMPLETED', 'DISPATCHED', 'SHIPPED', 'NA')
                                    AND (
                                        (ps_any.target_end_time IS NOT NULL AND ps_any.target_end_time != '0000-00-00 00:00:00' AND ps_any.target_end_time < NOW())
                                        OR (ps_any.stage_key = 'planningOrder' AND DATEDIFF(NOW(), o.order_booked_date) >= 1)
                                    )
                                )
                            )";
                        }


                    } else if (isset($queryParams['status']) && strtolower($queryParams['status']) === 'pending') {
                        // Orders with pending tasks in this department
                        $conditions[] = "EXISTS (
                            SELECT 1 FROM process_stages ps_dept 
                            WHERE ps_dept.order_id = o.id 
                            AND ps_dept.stage_key IN ($placeholders)
                            AND ps_dept.status IN ('PENDING', 'WIP', 'YTS', 'REVIEW', 'PARTIAL')
                            AND (
                                1=1
                            )
                        )";
                    } else if (isset($queryParams['status']) && (strtolower($queryParams['status']) === 'completed' || strtolower($queryParams['status']) === 'dispatched' || strtolower($queryParams['status']) === 'shipped')) {
                        // Orders FULLY completed/dispatched in this department
                        // (Must have at least one stage reached AND no stages should be pending)
                        $conditions[] = "EXISTS (
                            SELECT 1 FROM process_stages ps_dept_ex
                            WHERE ps_dept_ex.order_id = o.id 
                            AND ps_dept_ex.stage_key IN ($placeholders)
                            AND ps_dept_ex.status IN ('COMPLETED', 'DISPATCHED', 'SHIPPED', 'NA')
                                AND (
                                    1=1
                                )
                            ) AND NOT EXISTS (
                            SELECT 1 FROM process_stages ps_dept 
                            WHERE ps_dept.order_id = o.id 
                            AND ps_dept.stage_key IN ($placeholders)
                            AND ps_dept.status NOT IN ('COMPLETED', 'DISPATCHED', 'SHIPPED', 'NA')
                            AND (
                                1=1
                            )
                        )";
                    } else {
                        // Orders reaching this department (All Status)
                        $conditions[] = "EXISTS (
                            SELECT 1 FROM process_stages ps_dept 
                            WHERE ps_dept.order_id = o.id 
                            AND ps_dept.stage_key IN ($placeholders)
                            $statusCondition
                        )";
                    }
                    if (isset($queryParams['status']) && (strtolower($queryParams['status']) === 'completed' || strtolower($queryParams['status']) === 'dispatched' || strtolower($queryParams['status']) === 'shipped')) {
                        $params = array_merge($params, $deptStages, $deptStages);
                    } else {
                        $params = array_merge($params, $deptStages);
                    }
                } elseif ($searchTermActive) {
                    // If search is active, we don't add the EXISTS condition, 
                    // letting the global search handle it across all orders.
                }

                // NEW: Handle Delay Buckets based on the same dept stages (Match by worst delay in dept)
                $delayBucket = $queryParams['delay_bucket'] ?? null;
                if ($delayBucket && $delayBucket !== 'all' && !empty($deptStages)) {
                    $placeholders = implode(',', array_fill(0, count($deptStages), '?'));
                    $targetRank = 1; // white
                    
                    if ($delayBucket === 'black') $targetRank = 4;
                    else if ($delayBucket === 'red') $targetRank = 3;
                    else if ($delayBucket === 'yellow') $targetRank = 2;

                    $conditions[] = "(
                        SELECT MAX(CASE 
                            WHEN COALESCE(ps_b.target_end_time, '0000-00-00 00:00:00') != '0000-00-00 00:00:00' THEN
                                CASE 
                                    WHEN DATEDIFF(NOW(), ps_b.target_end_time) >= 21 THEN 4
                                    WHEN DATEDIFF(NOW(), ps_b.target_end_time) >= 14 THEN 3
                                    WHEN DATEDIFF(NOW(), ps_b.target_end_time) >= 7 THEN 2
                                    ELSE 1
                                END
                            ELSE
                                CASE 
                                    WHEN DATEDIFF(NOW(), o.order_booked_date) >= 21 THEN 4
                                    WHEN DATEDIFF(NOW(), o.order_booked_date) >= 14 THEN 3
                                    WHEN DATEDIFF(NOW(), o.order_booked_date) >= 7 THEN 2
                                    ELSE 1
                                END
                        END) 
                        FROM process_stages ps_b 
                        WHERE ps_b.order_id = o.id 
                        AND ps_b.stage_key IN ($placeholders)
                        AND ps_b.status = 'WIP'
                    ) = ?";
                    $params = array_merge($params, $deptStages, [$targetRank]);
                }
            }

            // Specific Stage Filtering (from Breakup List)
            $stageParam = $queryParams['stage'] ?? null;
            if ($stageParam && $stageParam !== 'all') {
                $sKeys = explode(',', $stageParam);
                $sPlaceholders = implode(',', array_fill(0, count($sKeys), '?'));
                $conditions[] = "EXISTS (SELECT 1 FROM process_stages ps_stage WHERE ps_stage.order_id = o.id AND ps_stage.stage_key IN ($sPlaceholders))";
                foreach($sKeys as $sk) $params[] = $sk;
            }

            // ROLE-BASED VISIBILITY
            // 1. Fetch fresh role from DB to avoid slate JWT issues
            $stmtRole = $pdo->prepare("SELECT role_name FROM user_roles WHERE user_id = ? LIMIT 1");
            $stmtRole->execute([$payload['user_id']]);
            $dbRole = $stmtRole->fetchColumn();
            
            // Normalize role: lowercase, trimmed, and spaces to underscores
            $roleInfo = $dbRole ? strtolower(trim(str_replace(' ', '_', $dbRole))) : strtolower(trim(str_replace(' ', '_', $payload['role'] ?? '')));
            
            // Debug Header (To verify in network tab)
            header("X-Debug-Role: $roleInfo");

            // DEBUG LOGGING: Log BEFORE the restriction check
            $logData = date('Y-m-d H:i:s') . " | User: {$payload['user_id']} | Role: $roleInfo\n";
            file_put_contents(__DIR__ . '/debug_orders.log', $logData, FILE_APPEND);

            // 2. Fetch Assigned Products (PRIORITY 1 RESTRICTION)
            $stmt = $pdo->prepare("SELECT product_name FROM user_product_assignments WHERE user_id = ?");
            $stmt->execute([$payload['user_id']]);
            $userProducts = $stmt->fetchAll(PDO::FETCH_COLUMN);

            // 3. Define Roles with Global (Full) Access Fallback
            // These roles see everything ONLY IF they have NO specific product assignments.
            $fullAccessRoles = [
                'admin', 'gm', 'planner', 'planning', 'management', 'accounts',
                'engineering', 'engineering_head', 'production', 'quality', 'quality_head',
                'purchase', 'purchase_head', 'automation_purchase', 'design', 'stores', 'hr',
                'sales', 'sales_head',
                'machining', 'machining_head', 'assembly', 'assembly_head',
                'painting', 'painting_head', 'dispatch', 'dispatch_head'
            ];

            $joinClause = "";
            
            // 0. ABSOLUTE BYPASS FOR GLOBAL ROLES
            if (in_array($roleInfo, ['admin', 'gm', 'planner', 'planning'])) {
                // Skip further visibility filters - they see everything
            } else {
                if ($roleInfo === 'automation_purchase') {
                    $conditions[] = "(o.is_automation = 1 OR o.product_category = 'Automation' OR LOWER(o.product_name) LIKE '%automation%' OR LOWER(o.product_group) LIKE '%automation%' OR LOWER(o.product_name) LIKE '%regulus%' OR LOWER(o.product_group) LIKE '%regulus%' OR LOWER(o.product_name) LIKE '%igd%' OR LOWER(o.product_group) LIKE '%igd%')";
                }
            // Sales always sees their region, even if products are also assigned.
            if (($roleInfo === 'sales' || $roleInfo === 'sales_head') && !in_array($roleInfo, ['admin', 'gm'])) {
                if (empty($userRegion)) {
                    $stmt = $pdo->prepare("SELECT region FROM users WHERE id = ?");
                    $stmt->execute([$payload['user_id']]);
                    $userRegion = $stmt->fetchColumn();
                }
                
                /* 
                if ($userRegion) {
                    $conditions[] = "o.region = ?";
                    $params[] = $userRegion;
                } else if (empty($userProducts)) {
                    // Sales with no region and no products: Hide everything
                    $conditions[] = "o.id IS NULL"; 
                }
                */
            }

            // 2. PRODUCT-BASED RESTRICTION (For Engineering)
            // Engineering roles see only orders matching their assigned products/groups.
            // HEAD roles usually want to see everything, so we only apply filter to non-head engineering roles.
            $isEngineeringGroup = (strpos($roleInfo, 'engineering') !== false) || ($roleInfo === 'design');
            $isHeadRole = (strpos($roleInfo, '_head') !== false) || (strpos($roleInfo, 'reviewer') !== false);
            
            if ($isEngineeringGroup && !$isHeadRole) {
                // Support product-based assignments OR explicit assigned_engineer / is_automation
                $userConds = [];
                
                // 1. Check if user has explicit product assignments
                if (!empty($userProducts)) {
                    $productConds = [];
                    foreach ($userProducts as $product) {
                        $productConds[] = "(o.product_name LIKE ? OR o.product_group LIKE ? OR o.product_model LIKE ?)";
                        $term = "%" . trim($product) . "%";
                        $params[] = $term;
                        $params[] = $term;
                        $params[] = $term;
                    }
                    if (!empty($productConds)) {
                        $userConds[] = "(" . implode(" OR ", $productConds) . ")";
                    }
                }
                
                // 2. Always allow orders where they are assigned, or if they are Gokul Prabhu and it is an automation order
                $assignCond = "(o.assigned_engineer = ? OR o.assigned_engineer LIKE ? OR o.assigned_engineer LIKE ? OR o.assigned_engineer LIKE ? OR (o.is_automation = 1 AND EXISTS (SELECT 1 FROM users WHERE id = ? AND name LIKE '%GOKUL%PRABU%')))";
                $params[] = $payload['user_id'];
                $params[] = "%," . $payload['user_id'] . "%";
                $params[] = $payload['user_id'] . ",%";
                $params[] = "%," . $payload['user_id'] . ",%";
                $params[] = $payload['user_id'];
                
                $userConds[] = $assignCond;
                
                // Combine with OR so that they see EITHER their assigned products OR their explicitly assigned/automation orders!
                $conditions[] = "(" . implode(" OR ", $userConds) . ")";
            } 
            
            } // End of non-global role restrictions
            
            // Dynamic Gear Portal filter
            require_once __DIR__ . '/../../utils/portal_helper.php';
            applyGearFilterIfRequired($conditions, 'o');
            
            $whereClause = $conditions ? 'WHERE ' . implode(' AND ', $conditions) : '';
            
            // Get total count (Safe)
            try {
                $countSql = "SELECT COUNT(DISTINCT o.id) as total FROM orders o $joinClause $whereClause";
                header("X-Debug-SQL-Count: " . str_replace(["\n", "\r"], ' ', $countSql));
                header("X-Debug-Params: " . json_encode($params));
                $stmt = $pdo->prepare($countSql);
                $stmt->execute($params);
                $total = $stmt->fetch()['total'];
            } catch (PDOException $e) {
                $total = 0;
                $debugError = "Total query failed: " . $e->getMessage();
            }

            // Get orders (Optimized column selection to save memory)
            $orders = [];
            try {
                $sql = "
                    SELECT o.id, o.customer_name, o.customer_email, o.location, o.sales_order_no, o.customer_po_no,
                           o.order_booked_date, o.expected_delivery_date, o.quantity, o.order_value,
                           o.product_group, o.product_name, o.work_order_no, o.line_item_id,
                           o.region, o.project_end_customer, o.product_category, o.pending_weeks, o.sales_invoice_date,
                           o.stpl_wo_no as stplWoNo, o.siipl_wo_no as siiplWoNo,
                           o.is_planned, o.planning_completed_at,
                           o.product_model, o.product_code, o.product_type, o.uom, o.rate, 
                           o.currency, o.conversion_rate, o.sales_order_date, o.customer_po_date,
                           o.stpl_wo_date, o.siipl_wo_date, o.remarks, o.solution,
                           o.product_description, o.product_technical_details, o.product_class,
                           o.order_value_currency, o.order_value_foreign, o.country, 
                           o.design_completion_percentage, o.qc_completion_percentage,
                           o.is_automation as isAutomation,
                           u_eng.name as assignedEngineer, o.review_status as reviewStatus
                    FROM orders o
                    LEFT JOIN users u_eng ON o.assigned_engineer = u_eng.id
                    $joinClause
                    $whereClause
                    GROUP BY o.id
                    ORDER BY o.order_booked_date DESC, o.id DESC
                    LIMIT $limit OFFSET $offset
                ";
                
                $stmt = $pdo->prepare($sql);
                $stmt->execute($params);
                $orders = $stmt->fetchAll();
            } catch (PDOException $e) {
                $debugError = ($debugError ?? "") . " | Orders query failed: " . $e->getMessage();
            }

            if (!empty($orders)) {
                // Bulk Fetch Optimization (Solve N+1 Problem)
                $orderIds = array_column($orders, 'id');
                $placeholders = implode(',', array_fill(0, count($orderIds), '?'));
                
                // 0. Get historical averages for risk prediction
                $historicalAverages = getHistoricalAverages($pdo);
                
                // 1. Bulk Fetch Stages
                try {
                    $stmt = $pdo->prepare("
                        SELECT ps.order_id, ps.stage_key, ps.status, ps.locked, ps.updated_at, ps.updated_by,
                            ps.target_duration_days, ps.target_end_time, ps.actual_start_time, ps.actual_end_time,
                            u.name as updatedByName
                        FROM process_stages ps
                        LEFT JOIN users u ON ps.updated_by = u.id
                        WHERE ps.order_id IN ($placeholders)
                        ORDER BY ps.updated_at DESC, ps.id DESC
                    ");
                    $stmt->execute($orderIds);
                    $allStages = $stmt->fetchAll();
                } catch (PDOException $e) {
                    // Fallback for missing columns
                    $stmt = $pdo->prepare("
                        SELECT order_id, stage_key, status, locked, updated_at, updated_by
                        FROM process_stages 
                        WHERE order_id IN ($placeholders)
                        ORDER BY updated_at DESC, id DESC
                    ");
                    $stmt->execute($orderIds);
                    $allStages = $stmt->fetchAll();
                }

                // Group stages by order_id
                $stagesByOrder = [];
                foreach ($allStages as $stage) {
                    $oid = $stage['order_id'];
                    $key = $stage['stage_key'];
                    if (!isset($stagesByOrder[$oid])) {
                        $stagesByOrder[$oid] = [];
                    }
                    
                    // Optimization: Use stage_key as index to avoid O(N^2) duplicate checks
                    // Only take the first one encountered (latest due to DESC order)
                    if (!isset($stagesByOrder[$oid][$key])) {
                        $stagesByOrder[$oid][$key] = $stage;
                    }
                }

                // Convert grouped stages to list format for prediction
                // However, calculateRisk expects the list, and merging data in memory uses key.
                // Let's refine the merging data part further down.

                // 2. Bulk Fetch Reviews (SELF-HEALING: fallback if extended columns missing)
                $allReviews = [];
                try {
                    $stmt = $pdo->prepare("
                        SELECT order_id, week_code, review_points, color_code, commitment_week, remarks,
                            objective, issue, rca, solution_temp, solution_perm, 
                            actions, decision, owner, measures, kpi, benefit, sustain
                        FROM weekly_reviews 
                        WHERE order_id IN ($placeholders)
                    ");
                    $stmt->execute($orderIds);
                    $allReviews = $stmt->fetchAll();
                } catch (Throwable $wrEx) {
                    // Fallback: fetch only basic columns if extended ones are missing
                    try {
                        $stmt = $pdo->prepare("
                            SELECT order_id, week_code, review_points, color_code, commitment_week, remarks
                            FROM weekly_reviews 
                            WHERE order_id IN ($placeholders)
                        ");
                        $stmt->execute($orderIds);
                        $allReviews = $stmt->fetchAll();
                    } catch (Throwable $wrEx2) {
                        $allReviews = []; // Table might not exist
                    }
                }

                // Group reviews by order_id
                $reviewsByOrder = [];
                foreach ($allReviews as $review) {
                    $reviewsByOrder[$review['order_id']][] = $review;
                }

                // 2.5 Bulk Fetch PERT Estimates for confidence calculation
                // SELF-HEALING: If table doesn't exist, create it and return empty results
                $pertEstimates = [];
                try {
                    $stmt = $pdo->prepare("
                        SELECT order_id, SUM(expected_time) as total_te, SUM(variance) as total_var
                        FROM order_pert_estimates 
                        WHERE order_id IN ($placeholders)
                        GROUP BY order_id
                    ");
                    $stmt->execute($orderIds);
                    $pertEstimates = $stmt->fetchAll(PDO::FETCH_UNIQUE | PDO::FETCH_ASSOC);
                } catch (Throwable $pertEx) {
                    // Table might not exist — create it silently and continue
                    try {
                        $pdo->exec("CREATE TABLE IF NOT EXISTS order_pert_estimates (
                            id CHAR(36) PRIMARY KEY,
                            order_id CHAR(36) NOT NULL,
                            stage_key VARCHAR(100) NOT NULL,
                            optimistic_time DECIMAL(10,2) DEFAULT NULL,
                            most_likely_time DECIMAL(10,2) DEFAULT NULL,
                            pessimistic_time DECIMAL(10,2) DEFAULT NULL,
                            expected_time DECIMAL(10,2) DEFAULT NULL,
                            variance DECIMAL(10,4) DEFAULT NULL,
                            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                            INDEX(order_id)
                        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");
                    } catch (Throwable $createEx) { /* ignore */ }
                    $pertEstimates = [];
                }

                // 2.75 Fetch Engineering Assignments (Only for specific roles)
                $engineerAssignments = [];
                $roleNorm = strtolower(trim(str_replace(' ', '_', $payload['role'] ?? '')));
                if (in_array($roleNorm, ['admin', 'gm', 'planner', 'planning', 'engineering_head'])) {
                    $stmtE = $pdo->query("
                        SELECT u.name, upa.product_name as keyword
                        FROM users u
                        JOIN user_roles ur ON u.id = ur.user_id
                        JOIN user_product_assignments upa ON u.id = upa.user_id
                        WHERE ur.role_name = 'engineering'
                    ");
                    $rawAssignments = $stmtE->fetchAll(PDO::FETCH_ASSOC);
                    
                    // Group keywords by engineer name
                    foreach ($rawAssignments as $ra) {
                        $engineerAssignments[$ra['name']][] = $ra['keyword'];
                    }
                }

                // Pre-calculate current time for risk functions
                $nowTime = time();
                
                // 3. Merge Data in Memory (EXTREME OPTIMIZATION)
                foreach ($orders as &$order) {
                    $oId = $order['id'];
                    
                    // Attach Assigned Engineer (Match keywords)
                    $matchedEngineers = [];
                    foreach ($engineerAssignments as $engName => $keywords) {
                        $hasMatch = false;
                        foreach ($keywords as $keyword) {
                            $keyword = trim($keyword);
                            if (empty($keyword)) continue;
                            
                            $splitKeys = preg_split('/\s+/', $keyword, -1, PREG_SPLIT_NO_EMPTY);
                            $allKeysMatch = true;
                            foreach ($splitKeys as $key) {
                                $keyLower = strtolower($key);
                                if (
                                    stripos($order['product_name'] ?? '', $keyLower) === false && 
                                    stripos($order['product_group'] ?? '', $keyLower) === false && 
                                    stripos($order['product_model'] ?? '', $keyLower) === false
                                ) {
                                    $allKeysMatch = false;
                                    break;
                                }
                            }
                            if ($allKeysMatch) {
                                $hasMatch = true;
                                break;
                            }
                        }
                        if ($hasMatch) {
                            $matchedEngineers[] = $engName;
                        }
                    }
                    if (empty($order['assignedEngineer'])) {
                        $order['assignedEngineer'] = implode(', ', array_unique($matchedEngineers));
                    }

                    // Attach Stages
                    if (isset($stagesByOrder[$oId])) {
                        foreach ($stagesByOrder[$oId] as $key => $stage) {
                            $displayKey = $key === 'finalInspection' ? 'quality' : $key;
                            $order[$displayKey] = [
                                'status' => $stage['status'],
                                'locked' => (bool)$stage['locked'],
                                'updatedAt' => $stage['updated_at'],
                                'updatedBy' => $stage['updated_by'],
                                'updatedByName' => $stage['updatedByName'] ?? null
                            ];
                            if (isset($stage['target_end_time'])) $order[$displayKey]['targetEndTime'] = $stage['target_end_time'];
                            if (isset($stage['actual_start_time'])) $order[$displayKey]['actualStartTime'] = $stage['actual_start_time'];
                            if (isset($stage['actual_end_time'])) $order[$displayKey]['actualEndTime'] = $stage['actual_end_time'];
                        }
                    }

                    // Defaults
                    foreach (['cylinderPurchase', 'springPurchase'] as $k) {
                        if (!isset($order[$k])) $order[$k] = ['status' => 'PENDING', 'locked' => false];
                    }

                    $order['weeklyReviews'] = $reviewsByOrder[$oId] ?? [];
                    
                    // Confidence
                    $order['schedule_confidence'] = 100.0;
                    if (isset($pertEstimates[$oId])) {
                        $p = $pertEstimates[$oId];
                        $bookedT = strtotime($order['order_booked_date']);
                        $eddT = strtotime($order['expected_delivery_date']);
                        $targetDays = round(($eddT - $bookedT) / 86400);
                        $order['schedule_confidence'] = round(calculatePertProbability($targetDays, (float)$p['total_te'], (float)$p['total_var']) * 100, 1);
                    }
                    
                    $order['prediction'] = isset($stagesByOrder[$oId]) ? calculateRisk($order, array_values($stagesByOrder[$oId]), $historicalAverages) : ['riskLevel' => 'LOW', 'reasons' => []];

                    // Manual camelCase + Unset snake_case to free memory
                    $order['salesOrderNo'] = $order['sales_order_no']; unset($order['sales_order_no']);
                    $order['customerName'] = $order['customer_name']; unset($order['customer_name']);
                    $order['customerEmail'] = $order['customer_email']; unset($order['customer_email']);
                    $order['productName'] = $order['product_name']; unset($order['product_name']);
                    $order['workOrderNo'] = $order['work_order_no']; unset($order['work_order_no']);
                    $order['lineItemId'] = $order['line_item_id']; unset($order['line_item_id']);
                    $order['expectedDeliveryDate'] = $order['expected_delivery_date']; unset($order['expected_delivery_date']);
                    $order['projectEndCustomer'] = $order['project_end_customer']; unset($order['project_end_customer']);
                    $order['customerPoNo'] = $order['customer_po_no']; unset($order['customer_po_no']);
                    $order['orderBookedDate'] = $order['order_booked_date']; unset($order['order_booked_date']);
                    $order['orderValue'] = (float)$order['order_value']; unset($order['order_value']);
                    $order['productGroup'] = $order['product_group']; unset($order['product_group']);
                    $order['productCategory'] = $order['product_category']; unset($order['product_category']);
                    $order['pendingWeeks'] = $order['pending_weeks']; unset($order['pending_weeks']);
                    $order['salesInvoiceDate'] = $order['sales_invoice_date']; unset($order['sales_invoice_date']);
                    $order['isPlanned'] = (int)($order['is_planned'] ?? 0) === 1; unset($order['is_planned']);
                    $order['planningCompletedAt'] = $order['planning_completed_at']; unset($order['planning_completed_at']);
                    
                    $order['designCompletionPercentage'] = (int)($order['design_completion_percentage'] ?? 0); unset($order['design_completion_percentage']);
                    $order['qcCompletionPercentage'] = (int)($order['qc_completion_percentage'] ?? 0); unset($order['qc_completion_percentage']);
                    
                    // New fields
                    if (isset($order['product_model'])) { $order['productModel'] = $order['product_model']; unset($order['product_model']); }
                    if (isset($order['product_code'])) { $order['productCode'] = $order['product_code']; unset($order['product_code']); }
                    if (isset($order['product_type'])) { $order['productType'] = $order['product_type']; unset($order['product_type']); }
                    if (isset($order['conversion_rate'])) { $order['conversionRate'] = (float)$order['conversion_rate']; unset($order['conversion_rate']); }
                    if (isset($order['sales_order_date'])) { $order['salesOrderDate'] = $order['sales_order_date']; unset($order['sales_order_date']); }
                    if (isset($order['customer_po_date'])) { $order['customerPoDate'] = $order['customer_po_date']; unset($order['customer_po_date']); }
                    if (isset($order['stpl_wo_date'])) { $order['stplWoDate'] = $order['stpl_wo_date']; unset($order['stpl_wo_date']); }
                    if (isset($order['siipl_wo_date'])) { $order['siiplWoDate'] = $order['siipl_wo_date']; unset($order['siipl_wo_date']); }
                    if (isset($order['product_description'])) { $order['productDescription'] = $order['product_description']; unset($order['product_description']); }
                    if (isset($order['product_technical_details'])) { $order['productTechnicalDetails'] = $order['product_technical_details']; unset($order['product_technical_details']); }
                    if (isset($order['product_class'])) { $order['productClass'] = $order['product_class']; unset($order['product_class']); }
                    if (isset($order['order_value_currency'])) { $order['orderValueCurrency'] = $order['order_value_currency']; unset($order['order_value_currency']); }
                    if (isset($order['order_value_foreign'])) { $order['orderValueForeign'] = (float)$order['order_value_foreign']; unset($order['order_value_foreign']); }
                    if (isset($order['assigned_engineer'])) { $order['assignedEngineer'] = $order['assigned_engineer']; unset($order['assigned_engineer']); }
                    if (isset($order['review_status'])) { $order['reviewStatus'] = $order['review_status']; unset($order['review_status']); }
                    // Flat columns that don't need changes but just listed for clarity: uom, rate, currency, remarks, solution
                }
                
                // Free up memory from temporary grouping arrays
                unset($stagesByOrder);
                unset($reviewsByOrder);
                unset($pertEstimates);
            }

            $monthlyCapacity = 0;
            $monthlyActualOutcome = 0;
            try { $monthlyCapacity = getMonthlyCapacity($pdo); } catch (Throwable $e) {}
            try { $monthlyActualOutcome = getMonthlyActualOutcome($pdo); } catch (Throwable $e) {}

            $responseData = [
                'orders' => $orders,
                'total' => (int)$total,
                'page' => $page,
                'limit' => $limit,
                'monthlyCapacity' => $monthlyCapacity,
                'monthlyActualOutcome' => $monthlyActualOutcome,
                'userRegion' => $userRegion,
                'sql_debug' => $sql // ADDED THIS
            ];

            if (isset($queryParams['debug'])) {
                $responseData['debug'] = [
                    'version' => 'v1.4-Audit',
                    'timestamp' => date('Y-m-d H:i:s'),
                    'user' => [
                        'id' => $payload['user_id'] ?? 'unknown',
                        'role' => $roleInfo ?? 'unknown',
                        'department' => $payload['department'] ?? 'unknown'
                    ],
                    'user_products' => $userProducts ?? [],
                    'query' => [
                        'count_sql' => $countSql ?? 'N/A',
                        'conditions' => $conditions,
                        'params' => $params,
                        'join' => $joinClause
                    ]
                ];
            }

            jsonResponse($responseData);
            
        } catch (Throwable $e) {
            // Broad catch: any PHP error, DB error, etc.
            errorResponse('Server Error: ' . $e->getMessage() . ' in ' . basename($e->getFile()) . ':' . $e->getLine(), 500);
        }
    }

    function handleCreateOrder(PDO $pdo, array $payload, array $data): void {
        //$data = getJsonBody(); // Passed as argument now
        
        $requiredFields = [
            'customerName', 'location', 'projectEndCustomer', 'salesOrderNo',
            'customerPoNo', 'orderBookedDate', 'expectedDeliveryDate',
            'quantity', 'orderValue', 'productGroup', 'productName',
            'lineItemId'
        ];
        
        $error = validateRequired($data, $requiredFields);
        if ($error) {
            errorResponse($error);
        }
        
        try {
            $pdo->beginTransaction();
            
            $orderId = generateUUID();
            
            // AUTO-GENERATE WORK ORDER NO
            $location = $data['location'];
            $stmt = $pdo->prepare("SELECT COUNT(*) as count FROM orders WHERE location = ?");
            $stmt->execute([$location]);
            $count = $stmt->fetch()['count'] + 1;
            $workOrderNo = $location . "-WO-" . str_pad($count, 4, '0', STR_PAD_LEFT);
            
            // CALCULATE PENDING WEEKS
            $edd = new DateTime($data['expectedDeliveryDate']);
            $now = new DateTime();
            $interval = $now->diff($edd);
            $pendingWeeks = ceil($interval->days / 7);
            if ($edd < $now) $pendingWeeks = 0; // Already overdue

            // AUTOMATIC DETECTION: Set is_automation to 1 if product fields contain keywords
            $productName = $data['productName'] ?? '';
            $productGroup = $data['productGroup'] ?? '';
            $productModel = $data['productModel'] ?? '';
            $remarks = $data['remarks'] ?? '';
            $isAuto = 0;
            $category = $data['productCategory'] ?? 'Std';
            
            if ($category === 'Automation') {
                $isAuto = 1;
            }
            
            $combinedText = strtolower($productName . ' ' . $productGroup . ' ' . $productModel);
            $remarksText = strtolower($remarks);
            
            if (preg_match('/automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad/', $combinedText) || 
                preg_match('/accessories|automation|positioner|bare gad|bracket drg|bracket drawing/', $remarksText)) {
                $isAuto = 1;
            }

            $stmt = $pdo->prepare("
                INSERT INTO orders (
                    id, customer_name, location, project_end_customer, sales_order_no,
                    customer_po_no, order_booked_date, expected_delivery_date,
                    quantity, order_value, product_group, product_name,
                    work_order_no, line_item_id, pending_weeks, created_by, region,
                    product_code, product_type, uom, rate, currency, conversion_rate,
                    sales_order_date, order_type, customer_po_date, product_description,
                    product_technical_details, product_class, order_value_currency,
                    stpl_wo_no, stpl_wo_date, siipl_wo_no, siipl_wo_date, remarks, solution, order_value_foreign, product_model,
                    product_category, sales_invoice_date, is_planned, country, is_automation
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?)
            ");
            
            $stmt->execute([
                $orderId,
                $data['customerName'],
                $location,
                $data['projectEndCustomer'],
                $data['salesOrderNo'],
                $data['customerPoNo'],
                $data['orderBookedDate'],
                $data['expectedDeliveryDate'],
                $data['quantity'],
                $data['orderValue'],
                $data['productGroup'],
                $data['productName'],
                $workOrderNo,
                $data['lineItemId'],
                $data['pendingWeeks'] ?? $pendingWeeks,
                $payload['user_id'],
                $data['region'] ?? null,
                $data['productCode'] ?? null,
                $data['productType'] ?? null,
                $data['uom'] ?? null,
                $data['rate'] ?? null,
                $data['currency'] ?? 'INR',
                $data['conversionRate'] ?? 1.0,
                $data['salesOrderDate'] ?? null,
                $data['orderType'] ?? null,
                $data['customerPoDate'] ?? null,
                $data['productDescription'] ?? null,
                $data['productTechnicalDetails'] ?? null,
                $data['productClass'] ?? null,
                $data['orderValueCurrency'] ?? null,
                $data['stplWoNo'] ?? null,
                $data['stplWoDate'] ?? null,
                $data['siiplWoNo'] ?? null,
                $data['siiplWoDate'] ?? null,
                $data['remarks'] ?? null,
                $data['solution'] ?? null,
                $data['orderValueForeign'] ?? 0,
                $data['productModel'] ?? null,
                $category,
                $data['salesInvoiceDate'] ?? null,
                $data['country'] ?? null,
                $isAuto
            ]);
            
            // Note: INITIALIZATION OF STAGES AND WEEKLY REVIEWS IS HANDLED BY 
            // THE DATABASE TRIGGER 'after_order_insert' ON THE 'orders' TABLE.
            // DO NOT MANUALLY INSERT THEM HERE TO AVOID DUPLICATES OR FK ERRORS.
            
            // AUTOMATIC LEAD TIME PLANNING
            require_once __DIR__ . '/../../utils/pmo_planner.php';
            applyLeadTimePlanning($pdo, $orderId);
            
            $pdo->commit();
            
            // 8. Auditing
            try {
                $auditLogger = new AuditLogger($pdo);
                $auditLogger->log(
                    $payload['user_id'], 
                    'CREATE_ORDER', 
                    'orders', 
                    $orderId, 
                    null, 
                    ['sales_order_no' => $data['salesOrderNo'], 'customer' => $data['customerName']]
                );
            } catch (Throwable $at) {
                // Ignore audit errors
            }
            
            // 9. Fetch the created order
            $stmt = $pdo->prepare("SELECT * FROM orders WHERE id = ?");
            $stmt->execute([$orderId]);
            $order = $stmt->fetch();
            $order = enrichOrderData($pdo, $order);
            
            jsonResponse($order, 201);
            
            // 10. NOTIFICATION ALERT: Notify Engineering/Quality when Planning creates an order
            $creatorRole = strtolower($payload['role'] ?? '');
            if (in_array($creatorRole, ['planner', 'planning', 'planning_head', 'admin'])) {
                try {
                    // Find recipients (Engineering Head, Reviewers, Quality Head)
                    $recipStmt = $pdo->query("
                        SELECT email, name, role FROM users 
                        WHERE role IN ('engineering_head', 'engineering_reviewer', 'quality_head', 'admin')
                        AND receive_emails = 1
                    ");
                    $recipients = $recipStmt->fetchAll();
                    
                    if (!empty($recipients)) {
                        $isAuto = (isset($order['isAutomation']) && $order['isAutomation']) || 
                                  (stripos($order['productName'] ?? '', 'automation') !== false);
                        
                        $subject = "🚨 New Work Order Created: " . $order['salesOrderNo'] . " (" . $order['customerName'] . ")";
                        
                        $emailBody = "
                        <div style='font-family: sans-serif; max-width: 600px; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;'>
                            <div style='background: #f8fafc; padding: 20px; border-bottom: 1px solid #e2e8f0;'>
                                <h2 style='margin: 0; color: #1e293b; font-size: 18px;'>New PMO Work Order Entry</h2>
                                <p style='margin: 5px 0 0; color: #64748b; font-size: 14px;'>Entry by Planning Team</p>
                            </div>
                            <div style='padding: 24px;'>
                                <table style='width: 100%; border-collapse: collapse;'>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px; width: 120px;'>Customer:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px; font-weight: bold;'>{$order['customerName']}</td>
                                    </tr>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>SO Number:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px; font-weight: bold;'>{$order['salesOrderNo']}</td>
                                    </tr>
                                     <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>WO Number:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px; font-weight: bold;'>{$order['workOrderNo']} / " . ($order['stplWoNo'] ?: $order['siiplWoNo'] ?: 'N/A') . "</td>
                                    </tr>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>Product:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px;'>{$order['productName']}</td>
                                    </tr>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>EDD:</td>
                                        <td style='padding: 8px 0; color: #e11d48; font-size: 14px; font-weight: bold;'>" . date('d M Y', strtotime($order['expectedDeliveryDate'])) . "</td>
                                    </tr>
                                    " . ($isAuto ? "
                                    <tr>
                                        <td style='padding: 12px; background: #f0f9ff; border-radius: 8px; color: #0369a1; font-size: 12px; font-weight: bold; text-align: center;' colspan='2'>
                                            ⚡ AUTOMATION WORK ORDER - ACTION REQUIRED
                                        </td>
                                    </tr>" : "") . "
                                </table>
                                
                                <div style='margin-top: 24px; text-align: center;'>
                                    <a href='https://gm.susingroup.com/pmo-tracking?search=" . urlencode($order['salesOrderNo']) . "' 
                                       style='background: #1e293b; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 14px; display: inline-block;'>
                                        View Order in PMO
                                    </a>
                                </div>
                            </div>
                            <div style='background: #f8fafc; padding: 15px; text-align: center; border-top: 1px solid #e2e8f0;'>
                                <p style='margin: 0; color: #94a3b8; font-size: 11px;'>This is an automated notification from Susin PMO System.</p>
                            </div>
                        </div>";
                        
                        foreach ($recipients as $r) {
                            sendEmail($r['email'], $subject, $emailBody, ['type' => 'new_order_alert', 'name' => $r['name'], 'user_id' => null]);
                        }
                    }
                } catch (Throwable $mailEx) {
                    error_log("Alert failed: " . $mailEx->getMessage());
                }
            }
            
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            
            // Integrity constraint violation (Duplicate, FK, etc.)
            if ($e->getCode() == '23000') {
                $msg = $e->getMessage();
                if (strpos($msg, 'sales_order_no') !== false) {
                    errorResponse('The Sales Order Number already exists. Please use a unique number.', 409);
                } else if (strpos($msg, 'line_item_id') !== false) {
                    errorResponse('The Line Item ID already exists. Each order must have a unique Line Item ID.', 409);
                } else if (strpos($msg, '1452') !== false || strpos($msg, 'foreign key') !== false) {
                    // Return the actual database error message so we can identify the failing constraint
                    errorResponse('Integrity Error: ' . $msg, 400);
                } else {
                    errorResponse('Conflict: ' . $msg, 409);
                }
            }
            
            error_log("Order creation error: " . $e->getMessage());
            errorResponse('Database error: ' . $e->getMessage(), 500);
        }
    }

    function enrichOrderData(PDO $pdo, array $order): array {
        // Get process stages - handle missing columns gracefully if migration hasn't run
        try {
            $stmt = $pdo->prepare("
                SELECT ps.stage_key, ps.status, ps.locked, ps.updated_at, ps.updated_by,
                    ps.target_duration_days, ps.target_end_time, ps.actual_start_time, ps.actual_end_time,
                    u.name as updatedByName
                FROM process_stages ps
                LEFT JOIN users u ON ps.updated_by = u.id
                WHERE ps.order_id = ?
                ORDER BY ps.updated_at DESC, ps.id DESC
            ");
            $stmt->execute([$order['id']]);
            $stages = $stmt->fetchAll();
        } catch (PDOException $e) {
            // Fallback for missing columns
            $stmt = $pdo->prepare("
                SELECT ps.stage_key, ps.status, ps.locked, ps.updated_at, ps.updated_by,
                    u.name as updatedByName
                FROM process_stages ps
                LEFT JOIN users u ON ps.updated_by = u.id
                WHERE ps.order_id = ?
                ORDER BY ps.updated_at DESC, ps.id DESC
            ");
            $stmt->execute([$order['id']]);
            $stages = $stmt->fetchAll();
        }
        
        foreach ($stages as $stage) {
            $key = $stage['stage_key'];
            // Since we ordered by updated_at DESC, the FIRST one we encounter for a key is the latest.
            if (!isset($order[$key])) {
                $order[$key] = [
                    'status' => $stage['status'],
                    'locked' => (bool)$stage['locked'],
                    'updatedAt' => $stage['updated_at'],
                    'updatedBy' => $stage['updated_by'],
                    'updatedByName' => $stage['updatedByName'] ?? null,
                    'targetDurationDays' => $stage['target_duration_days'] ?? null,
                    'targetEndTime' => $stage['target_end_time'] ?? null,
                    'actualStartTime' => $stage['actual_start_time'] ?? null,
                    'actualEndTime' => $stage['actual_end_time'] ?? null
                ];
            }
        }
        
        // Get weekly reviews
        $stmt = $pdo->prepare("
            SELECT week_code, review_points, color_code, commitment_week, remarks,
                objective, issue, rca, solution_temp, solution_perm, 
                actions, decision, owner, measures, kpi, benefit, sustain
            FROM weekly_reviews WHERE order_id = ?
        ");
        $stmt->execute([$order['id']]);
        $reviews = $stmt->fetchAll();
        
        $order['weeklyReviews'] = [];
        foreach ($reviews as $review) {
            $order['weeklyReviews'][$review['week_code']] = [
                'reviewPoints' => $review['review_points'] ?? '',
                'colorCode' => $review['color_code'],
                'commitmentWeek' => $review['commitment_week'],
                'remarks' => $review['remarks'] ?? '',
                'objective' => $review['objective'] ?? '',
                'issue' => $review['issue'] ?? '',
                'rca' => $review['rca'] ?? '',
                'solutionTemp' => $review['solution_temp'] ?? '',
                'solutionPerm' => $review['solution_perm'] ?? '',
                'actions' => $review['actions'] ?? '',
                'decision' => $review['decision'] ?? '',
                'owner' => $review['owner'] ?? '',
                'measures' => $review['measures'] ?? '',
                'kpi' => $review['kpi'] ?? '',
                'benefit' => $review['benefit'] ?? '',
                'sustain' => $review['sustain'] ?? ''
            ];
        }
        
        // Add PERT Confidence
        $order['schedule_confidence'] = 100.0;
        try {
            $stmt = $pdo->prepare("
                SELECT SUM(expected_time) as total_te, SUM(variance) as total_var
                FROM order_pert_estimates 
                WHERE order_id = ?
                GROUP BY order_id
            ");
            $stmt->execute([$order['id']]);
            $pert = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($pert) {
                $bookedDate = new DateTime($order['order_booked_date']);
                $eddDate = new DateTime($order['expected_delivery_date']);
                $target = $bookedDate->diff($eddDate)->days;
                
                $prob = calculatePertProbability(
                    $target, 
                    (float)$pert['total_te'], 
                    (float)$pert['total_var']
                );
                $order['schedule_confidence'] = round($prob * 100, 1);
            }
        } catch (Throwable $e) {
            // Fallback to 100.0
        }
        
        // Convert snake_case to camelCase for frontend
        return convertToCamelCase($order);
    }


    function handleDeleteOrder(PDO $pdo, array $payload, array $data): void {
        // Check permission: Only Admin, GM, or Planner
        $userRole = strtolower($payload['role'] ?? '');
        if (!in_array($userRole, ['admin', 'gm', 'planner', 'planning', 'sales', 'sales_head'])) {
            errorResponse('Unauthorized: Only Admin, GM, Planner, or Sales can delete orders.', 403);
        }
        
        // Support JSON body { ids: [...] } OR query param ?id=...
        $ids = $data['ids'] ?? [];
        if (empty($ids) && isset($_GET['id'])) {
            $ids = [$_GET['id']];
        }
        
        if (empty($ids) || !is_array($ids)) {
            errorResponse('Order IDs required for deletion.', 400);
        }
        
        try {
            $pdo->beginTransaction();
            
            // Prepare placeholders for IN clause
            $placeholders = implode(',', array_fill(0, count($ids), '?'));
            
            // 1. Delete dependent stages
            $stmt = $pdo->prepare("DELETE FROM process_stages WHERE order_id IN ($placeholders)");
            $stmt->execute($ids);
            
            // 2. Delete weekly reviews
            $stmt = $pdo->prepare("DELETE FROM weekly_reviews WHERE order_id IN ($placeholders)");
            $stmt->execute($ids);
            
            // 3. Delete comments
            $stmt = $pdo->prepare("DELETE FROM order_comments WHERE order_id IN ($placeholders)");
            $stmt->execute($ids);
            
            // 4. Delete QC records (tolerant if table missing)
            try {
                $stmt = $pdo->prepare("DELETE FROM order_qc WHERE order_id IN ($placeholders)");
                $stmt->execute($ids);
            } catch (Throwable $e) {}
            
            // 5. Delete Notifications linked to order
            try {
                $stmt = $pdo->prepare("DELETE FROM notifications WHERE order_id IN ($placeholders)");
                $stmt->execute($ids);
            } catch (Throwable $e) {}
            
            // 6. Delete PERT Estimates
            try {
                $stmt = $pdo->prepare("DELETE FROM order_pert_estimates WHERE order_id IN ($placeholders)");
                $stmt->execute($ids);
            } catch (Throwable $e) {}
            
            // 7. Finally Delete Orders
            $stmt = $pdo->prepare("DELETE FROM orders WHERE id IN ($placeholders)");
            $stmt->execute($ids);
            
            $count = $stmt->rowCount();
            
            $pdo->commit();

            // 8. Auditing
            try {
                $auditLogger = new AuditLogger($pdo);
                $auditLogger->log(
                    $payload['user_id'], 
                    'DELETE_ORDER', 
                    'orders', 
                    implode(', ', $ids), 
                    ['ids' => $ids],
                    null
                );
            } catch (Throwable $at) {}

            jsonResponse(['status' => 'success', 'deleted_count' => $count]);
            
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) {
                $pdo->rollBack();
            }
            errorResponse('Database error during deletion: ' . $e->getMessage(), 500);
        }
    }



