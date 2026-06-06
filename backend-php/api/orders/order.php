<?php
/**
 * GET /api/orders/:id - Get single order
 * PUT /api/orders/:id - Update order
 * DELETE /api/orders/:id - Delete order
 */

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/jwt.php';
require_once __DIR__ . '/../../utils/response.php';
require_once __DIR__ . '/../../utils/email.php';

setCorsHeaders();

// Helper: Convert snake_case keys to camelCase recursively
function convertToCamelCase($data) {
    if (is_array($data)) {
        $result = [];
        foreach ($data as $key => $value) {
            $camelKey = lcfirst(str_replace(' ', '', ucwords(str_replace('_', ' ', $key))));
            $result[$camelKey] = convertToCamelCase($value);
        }
        return $result;
    }
    return $data;
}

$pdo = getDBConnection();
ensureSchemaColumns($pdo);
$payload = requireAuth();

// Get order ID from URL
$orderId = $_GET['id'] ?? null;

if (!$orderId) {
    errorResponse('Order ID required');
}

switch ($_SERVER['REQUEST_METHOD']) {
    case 'GET':
        handleGetOrder($pdo, $orderId);
        break;
    case 'PUT':
        handleUpdateOrder($pdo, $orderId, $payload);
        break;
    case 'DELETE':
        handleDeleteOrder($pdo, $orderId, $payload);
        break;
    default:
        errorResponse('Method not allowed', 405);
}

function handleGetOrder(PDO $pdo, string $orderId): void {
    try {
        $stmt = $pdo->prepare("SELECT * FROM orders WHERE id = ?");
        $stmt->execute([$orderId]);
        $order = $stmt->fetch();
        
        if (!$order) {
            errorResponse('Order not found', 404);
        }
        
        $order = enrichOrderData($pdo, $order);
        jsonResponse($order);
        
    } catch (PDOException $e) {
        errorResponse('Database error', 500);
    }
}

function handleUpdateOrder(PDO $pdo, string $orderId, array $payload): void {
    // EMERGENCY FORCE: Ensure the column exists before any update
    try {
        $pdo->exec("ALTER TABLE orders ADD COLUMN is_automation TINYINT(1) DEFAULT 0");
    } catch (Throwable $e) {
    }

    $data = getJsonBody();
    
    try {
        // Check order exists
        $stmt = $pdo->prepare("SELECT id FROM orders WHERE id = ?");
        $stmt->execute([$orderId]);
        if (!$stmt->fetch()) {
            errorResponse('Order not found', 404);
        }
        
        // Build update query dynamically
        $allowedFields = [
            'customerName' => 'customer_name',
            'location' => 'location',
            'projectEndCustomer' => 'project_end_customer',
            'customerPoNo' => 'customer_po_no',
            'expectedDeliveryDate' => 'expected_delivery_date',
            'quantity' => 'quantity',
            'orderValue' => 'order_value',
            'productGroup' => 'product_group',
            'productName' => 'product_name',
            'productCode' => 'product_code',
            'productType' => 'product_type',
            'uom' => 'uom',
            'rate' => 'rate',
            'currency' => 'currency',
            'conversionRate' => 'conversion_rate',
            'salesOrderDate' => 'sales_order_date',
            'orderType' => 'order_type',
            'customerPoDate' => 'customer_po_date',
            'productModel' => 'product_model',
            'orderValueCurrency' => 'order_value_currency',
            'stplWoNo' => 'stpl_wo_no',
            'siiplWoNo' => 'siipl_wo_no',
            'remarks' => 'remarks',
            'orderValueForeign' => 'order_value_foreign',
            'productDescription' => 'product_description',
            'productTechnicalDetails' => 'product_technical_details',
            'productClass' => 'product_class',
            'solution' => 'solution',
            'stplWoDate' => 'stpl_wo_date',
            'siiplWoDate' => 'siipl_wo_date',
            'productCategory' => 'product_category',
            'salesInvoiceDate' => 'sales_invoice_date',
            'salesOrderNo' => 'sales_order_no',
            'orderBookedDate' => 'order_booked_date',
            'workOrderNo' => 'work_order_no',
            'lineItemId' => 'line_item_id',
            'country' => 'country',
            'region' => 'region',
            'assignedEngineer' => 'assigned_engineer',
            'reviewStatus' => 'review_status',
            'designCompletionPercentage' => 'design_completion_percentage',
            'qcCompletionPercentage' => 'qc_completion_percentage',
            'isAutomation' => 'is_automation'
        ];
        
        $updates = [];
        $params = [];
        
        foreach ($allowedFields as $camelCase => $snakeCase) {
            if (array_key_exists($camelCase, $data)) {
                $updates[] = "$snakeCase = ?";
                $params[] = $data[$camelCase];
            }
        }
        
        if (empty($updates)) {
            errorResponse('No valid fields to update');
        }
        
        $params[] = $orderId;
        $sql = "UPDATE orders SET " . implode(', ', $updates) . " WHERE id = ?";
        
        // DETECT ASSIGNMENT CHANGE FOR NOTIFICATION AND AUDITING
        $oldOrder = $pdo->query("SELECT * FROM orders WHERE id = " . $pdo->quote($orderId))->fetch(PDO::FETCH_ASSOC);
        $oldDesigner = $oldOrder['assigned_engineer'] ?? null;

        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);

        // AUTO-SYNC: If product category was manually updated
        if (isset($data['productCategory'])) {
            if ($data['productCategory'] === 'Automation') {
                $pdo->exec("UPDATE orders SET is_automation = 1 WHERE id = " . $pdo->quote($orderId));
            } else if ($data['productCategory'] === 'Std') {
                $pdo->exec("UPDATE orders 
                            SET is_automation = 0 
                            WHERE id = " . $pdo->quote($orderId) . "
                            AND LOWER(product_name) NOT REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' 
                            AND LOWER(product_group) NOT REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad'
                            AND LOWER(product_model) NOT REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad'
                            AND LOWER(remarks) NOT REGEXP 'accessories|automation|positioner|bare gad|bracket drg|bracket drawing'");
            }
        }

        // AUTO-SYNC: If product details changed, re-evaluate is_automation
        if (isset($data['productName']) || isset($data['productGroup']) || isset($data['productModel']) || isset($data['remarks'])) {
             $pdo->exec("UPDATE orders 
                        SET is_automation = 1, product_category = 'Automation'
                        WHERE id = " . $pdo->quote($orderId) . "
                        AND (
                            LOWER(product_name) REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' OR 
                            LOWER(product_group) REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' OR 
                            LOWER(product_model) REGEXP 'automation|igd|regulus|isd|pld|pls|isr|hda|pd [0-9]|pd-[0-9]|pd140|pd160|bare gad' OR
                            LOWER(remarks) REGEXP 'accessories|automation|positioner|bare gad|bracket drg|bracket drawing'
                        )
                        AND (is_automation = 0 OR product_category = 'Std' OR product_category = '')");
        }

        // 10. NOTIFICATION ALERT: Notify Designers only if they are NEWLY added
        if (isset($data['assignedEngineer']) && $data['assignedEngineer'] && $data['assignedEngineer'] !== $oldDesigner && $data['assignedEngineer'] !== 'none') {
            try {
                $newAssignees = array_filter(array_map('trim', explode(',', $data['assignedEngineer'])));
                $oldAssignees = array_filter(array_map('trim', explode(',', $oldDesigner || '')));
                
                // Find only the IDs/Names that are in NEW but NOT in OLD
                $addedAssignees = array_diff($newAssignees, $oldAssignees);
                
                if (!empty($addedAssignees)) {
                    $placeholders = implode(',', array_fill(0, count($addedAssignees), '?'));
                    $recipStmt = $pdo->prepare("SELECT email, name FROM users WHERE (id IN ($placeholders) OR name IN ($placeholders)) AND receive_emails = 1");
                    $recipStmt->execute(array_merge($addedAssignees, $addedAssignees));
                    $recipients = $recipStmt->fetchAll();
                    
                    if (!empty($recipients)) {
                        // Fetch full order for context
                        $fullOrder = $pdo->query("SELECT * FROM orders WHERE id = " . $pdo->quote($orderId))->fetch(PDO::FETCH_ASSOC);
                        
                        $subject = "📋 New Work Order Assigned: " . ($fullOrder['sales_order_no'] ?? 'N/A');
                        
                        $emailBody = "
                        <div style='font-family: sans-serif; max-width: 600px; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden;'>
                            <div style='background: #f8fafc; padding: 20px; border-bottom: 1px solid #e2e8f0;'>
                                <h2 style='margin: 0; color: #1e293b; font-size: 18px;'>New Task Allocation</h2>
                                <p style='margin: 5px 0 0; color: #64748b; font-size: 14px;'>You have been assigned to a new Work Order</p>
                            </div>
                            <div style='padding: 24px;'>
                                <table style='width: 100%; border-collapse: collapse;'>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px; width: 120px;'>Customer:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px; font-weight: bold;'>{$fullOrder['customer_name']}</td>
                                    </tr>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>SO Number:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px; font-weight: bold;'>{$fullOrder['sales_order_no']}</td>
                                    </tr>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>Product:</td>
                                        <td style='padding: 8px 0; color: #1e293b; font-size: 14px;'>{$fullOrder['product_name']}</td>
                                    </tr>
                                    <tr>
                                        <td style='padding: 8px 0; color: #64748b; font-size: 13px;'>EDD:</td>
                                        <td style='padding: 8px 0; color: #e11d48; font-size: 14px; font-weight: bold;'>" . date('d M Y', strtotime($fullOrder['expected_delivery_date'])) . "</td>
                                    </tr>
                                </table>
                                
                                <div style='margin-top: 24px; text-align: center;'>
                                    <a href='https://gm.susingroup.com/pmo-tracking?search=" . urlencode($fullOrder['sales_order_no']) . "' 
                                       style='background: #1e293b; color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; font-weight: bold; font-size: 14px; display: inline-block;'>
                                        Open Dashboard to Start
                                    </a>
                                </div>
                            </div>
                            <div style='background: #f8fafc; padding: 15px; text-align: center; border-top: 1px solid #e2e8f0;'>
                                <p style='margin: 0; color: #94a3b8; font-size: 11px;'>This is an automated notification from Susin PMO System.</p>
                            </div>
                        </div>";
                        
                        foreach ($recipients as $r) {
                            sendEmail($r['email'], $subject, $emailBody, ['type' => 'assignment_alert', 'name' => $r['name']]);
                        }
                    }
                }
            } catch (Throwable $mailEx) {
                error_log("Assignment mail failed: " . $mailEx->getMessage());
            }
        }
        // Return updated order
        $stmt = $pdo->prepare("SELECT * FROM orders WHERE id = ?");
        $stmt->execute([$orderId]);
        $order = $stmt->fetch();

        // 8. Auditing
        try {
            if ($oldOrder) {
                require_once __DIR__ . '/../../utils/auditLog.php';
                $auditLogger = new AuditLogger($pdo);
                
                // Build old vs new changed fields
                $changedOld = [];
                $changedNew = [];
                foreach ($oldOrder as $key => $val) {
                    if (array_key_exists($key, $order) && $order[$key] !== $val) {
                        $changedOld[$key] = $val;
                        $changedNew[$key] = $order[$key];
                    }
                }
                
                if (!empty($changedNew)) {
                    $auditLogger->log(
                        $payload['user_id'],
                        'ORDER_MODIFIED',
                        'orders',
                        $orderId,
                        $changedOld,
                        $changedNew
                    );
                }
            }
        } catch (Throwable $at) {
            error_log("Audit logging failed: " . $at->getMessage());
        }

        // RE-CALCULATE PLANNING if relevant fields changed
        $planningFields = ['product_group', 'product_type', 'order_type', 'product_category', 'order_booked_date', 'is_automation'];
        $shouldReplan = false;
        foreach ($planningFields as $f) {
            // Check if this field was in the update params
            foreach ($allowedFields as $camel => $snake) {
                if ($snake === $f && isset($data[$camel])) {
                    $shouldReplan = true;
                    break 2;
                }
            }
        }

        if ($shouldReplan) {
            require_once __DIR__ . '/../../utils/pmo_planner.php';
            applyLeadTimePlanning($pdo, $orderId);
        }
        
        $order = enrichOrderData($pdo, $order);
        jsonResponse($order);
        
    } catch (PDOException $e) {
        errorResponse('Database error', 500);
    }
}

function handleDeleteOrder(PDO $pdo, string $orderId, array $payload): void {
    // Only admin can delete
    if ($payload['role'] !== 'admin') {
        errorResponse('Only admin can delete orders', 403);
    }
    
    try {
        $stmt = $pdo->prepare("DELETE FROM orders WHERE id = ?");
        $stmt->execute([$orderId]);
        
        if ($stmt->rowCount() === 0) {
            errorResponse('Order not found', 404);
        }
        
        jsonResponse(['message' => 'Order deleted successfully']);
        
    } catch (PDOException $e) {
        errorResponse('Database error', 500);
    }
}

function enrichOrderData(PDO $pdo, array $order): array {
    $stmt = $pdo->prepare("
        SELECT stage_key, status, locked, updated_at, updated_by,
               target_duration_days, target_end_time, actual_start_time, actual_end_time
        FROM process_stages 
        WHERE order_id = ?
        ORDER BY updated_at DESC, id DESC
    ");
    $stmt->execute([$order['id']]);
    $stages = $stmt->fetchAll();
    
    foreach ($stages as $stage) {
        $key = $stage['stage_key'];
        // DUPLICATE PROTECTION: Since we sort DESC, take only the first (latest) occurrence
        if (isset($order[$key]) && is_array($order[$key])) continue;

        $order[$key] = [
            'status' => $stage['status'],
            'locked' => (bool)$stage['locked'],
            'updatedAt' => $stage['updated_at'],
            'updatedBy' => $stage['updated_by'],
            'targetDurationDays' => $stage['target_duration_days'],
            'targetEndTime' => $stage['target_end_time'],
            'actualStartTime' => $stage['actual_start_time'],
            'actualEndTime' => $stage['actual_end_time']
        ];
    }
    
    $stmt = $pdo->prepare("
        SELECT week_code, review_points, color_code, commitment_week, remarks
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
            'remarks' => $review['remarks'] ?? ''
        ];
    }
    
    // RESOLVE ASSIGNED ENGINEER NAMES AND PRODUCT KEYWORDS EXACTLY LIKE INDEX.PHP
    $assignedEngineer = '';
    if (!empty($order['assigned_engineer'])) {
        $stmtName = $pdo->prepare("SELECT name FROM users WHERE id = ?");
        $stmtName->execute([$order['assigned_engineer']]);
        $assignedEngineer = $stmtName->fetchColumn() ?: '';
    }
    
    try {
        $stmtE = $pdo->query("
            SELECT u.name, upa.product_name as keyword
            FROM users u
            JOIN user_roles ur ON u.id = ur.user_id
            JOIN user_product_assignments upa ON u.id = upa.user_id
            WHERE ur.role_name = 'engineering'
        ");
        $rawAssignments = $stmtE->fetchAll(PDO::FETCH_ASSOC);
        
        $engineerAssignments = [];
        foreach ($rawAssignments as $ra) {
            $engineerAssignments[$ra['name']][] = $ra['keyword'];
        }
        
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
        
        if (!empty($matchedEngineers)) {
            if (!empty($assignedEngineer)) {
                $matchedEngineers[] = $assignedEngineer;
            }
            $assignedEngineer = implode(', ', array_unique($matchedEngineers));
        }
    } catch (Throwable $e) {}
    
    $order['assigned_engineer'] = $assignedEngineer;
    
    // MANUAL CAMELCASE + VALUE CASTING TO PREVENT MISMATCHES
    $order['salesOrderNo'] = $order['sales_order_no'] ?? null;
    $order['customerName'] = $order['customer_name'] ?? null;
    $order['customerEmail'] = $order['customer_email'] ?? null;
    $order['productName'] = $order['product_name'] ?? null;
    $order['workOrderNo'] = $order['work_order_no'] ?? null;
    $order['lineItemId'] = $order['line_item_id'] ?? null;
    $order['expectedDeliveryDate'] = $order['expected_delivery_date'] ?? null;
    $order['projectEndCustomer'] = $order['project_end_customer'] ?? null;
    $order['customerPoNo'] = $order['customer_po_no'] ?? null;
    $order['orderBookedDate'] = $order['order_booked_date'] ?? null;
    $order['orderValue'] = isset($order['order_value']) ? (float)$order['order_value'] : null;
    $order['productGroup'] = $order['product_group'] ?? null;
    $order['productCategory'] = $order['product_category'] ?? null;
    $order['pendingWeeks'] = $order['pending_weeks'] ?? null;
    $order['salesInvoiceDate'] = $order['sales_invoice_date'] ?? null;
    $order['isPlanned'] = isset($order['is_planned']) ? (int)$order['is_planned'] === 1 : true;
    $order['planningCompletedAt'] = $order['planning_completed_at'] ?? null;
    
    $order['designCompletionPercentage'] = (int)($order['design_completion_percentage'] ?? 0);
    $order['qcCompletionPercentage'] = (int)($order['qc_completion_percentage'] ?? 0);
    
    if (isset($order['product_model'])) { $order['productModel'] = $order['product_model']; }
    if (isset($order['product_code'])) { $order['productCode'] = $order['product_code']; }
    if (isset($order['product_type'])) { $order['productType'] = $order['product_type']; }
    if (isset($order['conversion_rate'])) { $order['conversionRate'] = (float)$order['conversion_rate']; }
    if (isset($order['sales_order_date'])) { $order['salesOrderDate'] = $order['sales_order_date']; }
    if (isset($order['customer_po_date'])) { $order['customerPoDate'] = $order['customer_po_date']; }
    if (isset($order['stpl_wo_date'])) { $order['stplWoDate'] = $order['stpl_wo_date']; }
    if (isset($order['siipl_wo_date'])) { $order['siiplWoDate'] = $order['siipl_wo_date']; }
    if (isset($order['is_automation'])) { $order['isAutomation'] = (int)$order['is_automation'] === 1; }
    
    $order['assignedEngineer'] = $order['assigned_engineer'];
    
    return convertToCamelCase($order);
}

/**
 * Helper to ensure schema is up to date (Optimized with lock)
 */
function ensureSchemaColumns(PDO $pdo) {
    $lockFile = __DIR__ . '/.orders_schema_applied_v22';
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
            'product_category' => "ENUM('Std', 'NPD', 'Customised', 'Automation', 'Spare', 'IOD') DEFAULT 'Std'",
            'sales_invoice_date' => "DATE DEFAULT NULL",
            'assigned_engineer' => "VARCHAR(36) DEFAULT NULL",
            'review_status' => "ENUM('WIP', 'COMPLETED', 'HOLD') DEFAULT 'WIP'",
            'design_completion_percentage' => "INT DEFAULT 0",
            'qc_completion_percentage' => "INT DEFAULT 0",
            'is_automation' => "TINYINT(1) DEFAULT 0",
            'dispatched_quantity' => "INT DEFAULT 0",
            'dispatched_value' => "DECIMAL(15, 2) DEFAULT 0.00",
            'country' => "VARCHAR(100) DEFAULT NULL",
            'region' => "VARCHAR(100) DEFAULT NULL"
        ];

        foreach ($columns as $column => $definition) {
            $stmt = $pdo->prepare("SHOW COLUMNS FROM orders LIKE ?");
            $stmt->execute([$column]);
            if (!$stmt->fetch()) {
                $pdo->exec("ALTER TABLE orders ADD COLUMN $column $definition");
            } else if ($column === 'product_category') {
                $pdo->exec("ALTER TABLE orders MODIFY COLUMN product_category $definition");
            }
        }
        
        // Initialize Lead Time Master
        ensureLeadTimeMaster($pdo);
        
        file_put_contents($lockFile, date('Y-m-d H:i:s'));
    } catch (Throwable $e) {}
}

/**
 * Ensures lead_time_master table exists and is seeded with templates
 */
function ensureLeadTimeMaster(PDO $pdo) {
    // 1. Create table
    $sql = "CREATE TABLE IF NOT EXISTS lead_time_master (
        id CHAR(36) PRIMARY KEY,
        group_name VARCHAR(100),
        order_type VARCHAR(100),
        product_type VARCHAR(255),
        total_days INT,
        gadSubmission INT DEFAULT 0,
        customerGadApproval INT DEFAULT 0,
        manufacturingDrawingBom INT DEFAULT 0,
        automationDrawing INT DEFAULT 0,
        erpBomActuator INT DEFAULT 0,
        erpBomAutomation INT DEFAULT 0,
        storesStockVerification INT DEFAULT 0,
        rawMaterialPurchase INT DEFAULT 0,
        productionMachining INT DEFAULT 0,
        cylinderPurchase INT DEFAULT 0,
        springPurchase INT DEFAULT 0,
        boughtOutPartsPurchase INT DEFAULT 0,
        automationPartsPurchase INT DEFAULT 0,
        assemblyActuator INT DEFAULT 0,
        painting INT DEFAULT 0,
        finalAssembly INT DEFAULT 0,
        quality INT DEFAULT 0,
        packing INT DEFAULT 0,
        dispatch INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX(group_name, order_type, product_type)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";
    $pdo->exec($sql);

    // 2. Check if already seeded (Avoid overhead on every request)
    $stmt = $pdo->query("SELECT COUNT(*) FROM lead_time_master");
    if ($stmt->fetchColumn() > 0) return;

    // 3. Seed data
    $data = [
        ['ISR/ICR SERIES', 'STANDARD', 'Actuator+GB+AT', 82, 3, 7, 2, 6, 2, 2, 2, 28, 26, 42, 56, 52, 42, 5, 4, 1, 1, 1, 0],
        ['ISD/ICD SERIES', 'STANDARD', 'Actuator+GB+AT', 67, 3, 6, 2, 6, 2, 2, 2, 28, 26, 42, 0, 42, 42, 5, 4, 1, 1, 1, 0],
        ['PD/PS SERIES', 'STANDARD', 'Actuator+GB+AT', 57, 3, 5, 1, 4, 1, 2, 1, 14, 21, 0, 0, 14, 42, 3, 0, 1, 1, 1, 0],
        ['PLS SERIES', 'STANDARD', 'Actuator+GB+AT', 82, 3, 7, 2, 6, 2, 2, 2, 28, 26, 42, 56, 52, 42, 5, 4, 1, 1, 1, 0],
        ['PLD SERIES', 'STANDARD', 'Actuator+GB+AT', 67, 3, 6, 2, 6, 2, 2, 2, 28, 28, 42, 0, 42, 42, 4, 4, 1, 1, 1, 0],
        ['ACCESSORIES', 'STANDARD', 'ACCESSORIES', 41, 0, 0, 0, 6, 0, 2, 2, 0, 0, 0, 0, 7, 28, 0, 0, 0, 1, 1, 0],
        ['ISR/ICR SERIES', 'STANDARD', 'Actuator+AT(MODULATING)', 110, 6, 7, 2, 6, 2, 2, 2, 28, 26, 42, 56, 52, 81, 5, 4, 1, 1, 1, 0],
        ['ISD/ICD SERIES', 'STANDARD', 'Actuator+AT(MODULATING)', 109, 6, 6, 2, 6, 2, 2, 2, 28, 26, 42, 0, 42, 84, 4, 4, 1, 1, 1, 0],
        ['PDPS SERIES', 'STANDARD', 'Actuator+GB+AT(MODULATING)', 100, 6, 6, 2, 4, 1, 2, 1, 14, 21, 0, 0, 14, 84, 3, 0, 1, 1, 1, 0],
        ['PLS SERIES', 'STANDARD', 'Actuator+GB+AT(MODULATING)', 110, 6, 7, 2, 6, 2, 2, 2, 28, 26, 42, 56, 52, 84, 5, 4, 1, 1, 1, 0],
        ['PLD SERIES', 'STANDARD', 'Actuator+GB+AT(MODULATING)', 109, 6, 6, 2, 6, 2, 2, 2, 28, 28, 42, 0, 42, 84, 4, 4, 1, 1, 1, 0],
        ['ISR/ICR SERIES', 'CUSTOMISED', 'CUS-Actuator+GB+AT', 96, 6, 7, 7, 6, 2, 2, 2, 28, 35, 42, 63, 35, 42, 5, 6, 1, 1, 1, 0],
        ['ISD/ICD SERIES', 'CUSTOMISED', 'CUS-Actuator+GB+AT', 74, 6, 7, 7, 6, 2, 2, 2, 28, 28, 42, 0, 35, 42, 4, 6, 1, 1, 1, 0],
        ['PD/PS SERIES', 'CUSTOMISED', 'CUS-Actuator+GB+AT', 62, 4, 7, 7, 4, 1, 2, 1, 14, 21, 0, 0, 14, 42, 3, 4, 1, 1, 1, 0],
        ['PLS SERIES', 'CUSTOMISED', 'CUS-Actuator+GB+AT', 96, 6, 7, 7, 6, 2, 2, 2, 28, 35, 42, 63, 35, 42, 5, 6, 1, 1, 1, 0],
        ['PLD SERIES', 'CUSTOMISED', 'CUS-Actuator+GB', 74, 6, 7, 7, 6, 2, 2, 2, 28, 28, 42, 0, 35, 42, 4, 6, 1, 1, 1, 0],
        ['ISR/ICR SERIES', 'STANDARD', 'Actuator', 67, 1, 7, 1, 6, 1, 2, 2, 21, 21, 42, 49, 28, 0, 4, 4, 1, 1, 1, 0],
        ['ISD/ICD SERIES', 'STANDARD', 'Actuator', 57, 3, 6, 2, 6, 2, 2, 2, 28, 28, 42, 0, 42, 0, 4, 4, 1, 1, 1, 0],
        ['PD/PS SERIES', 'STANDARD', 'Actuator', 31, 1, 7, 1, 0, 1, 0, 2, 21, 21, 0, 0, 21, 0, 3, 0, 1, 1, 1, 0],
        ['PLS SERIES', 'STANDARD', 'Actuator', 71, 1, 7, 1, 0, 1, 0, 2, 21, 28, 42, 56, 28, 0, 4, 4, 1, 1, 1, 0],
        ['PLD SERIES', 'STANDARD', 'Actuator', 57, 1, 7, 1, 0, 1, 0, 2, 21, 28, 42, 0, 28, 0, 4, 4, 1, 1, 1, 0],
        ['ITG/MAW/MAB SERIES', 'STANDARD', 'Actuator', 42, 2, 6, 2, 0, 1, 0, 2, 28, 28, 0, 0, 28, 0, 4, 2, 1, 1, 1, 0],
        ['ISR/ICR SERIES', 'CUSTOMISED', 'CUS-Actuator', 87, 6, 7, 7, 1, 1, 0, 2, 28, 28, 42, 63, 28, 0, 5, 5, 1, 1, 1, 0],
        ['ISD/ICD SERIES', 'CUSTOMISED', 'CUS-Actuator', 72, 6, 7, 7, 6, 2, 2, 2, 28, 28, 42, 0, 42, 0, 4, 5, 1, 1, 1, 0],
        ['PD/PS SERIES', 'CUSTOMISED', 'CUS-Actuator', 52, 4, 7, 7, 1, 1, 0, 1, 14, 21, 0, 28, 28, 0, 3, 5, 1, 1, 1, 0],
        ['PLS SERIES', 'CUSTOMISED', 'CUS-Actuator', 87, 6, 7, 7, 1, 1, 0, 2, 28, 35, 42, 63, 28, 0, 5, 5, 1, 1, 1, 0],
        ['PLD SERIES', 'CUSTOMISED', 'CUS-Actuator', 66, 6, 7, 7, 1, 1, 0, 2, 21, 28, 42, 0, 28, 0, 5, 5, 1, 1, 1, 0],
        ['ITG/MAW/MAB SERIES', 'CUSTOMISED', 'CUS-Actuator', 53, 6, 7, 7, 1, 1, 1, 2, 28, 28, 0, 0, 21, 0, 5, 4, 1, 1, 1, 0],
        ['ITS SERIES', 'STANDARD', 'ITS SERIES', 43, 0, 0, 0, 0, 2, 0, 2, 21, 21, 0, 0, 28, 0, 4, 4, 1, 1, 1, 0],
        ['SEAL KIT', 'STANDARD', 'SEAL KIT', 27, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 21, 0, 0, 0, 1, 1, 1, 0],
        ['SERVICE (Against Order Requred)', 'CUSTOMISED', 'SERVICE (Against Order Required)', 27, 0, 0, 0, 0, 0, 2, 2, 0, 0, 0, 0, 21, 0, 0, 0, 1, 1, 1, 0],
        ['NPD', 'NPD', 'NPD', 143, 21, 21, 14, 12, 2, 0, 1, 28, 35, 42, 56, 52, 0, 6, 6, 1, 2, 1, 0]
    ];

    $stmt = $pdo->prepare("INSERT INTO lead_time_master (
        id, group_name, order_type, product_type, total_days,
        gadSubmission, customerGadApproval, manufacturingDrawingBom,
        automationDrawing, erpBomActuator, erpBomAutomation,
        storesStockVerification, rawMaterialPurchase, productionMachining,
        cylinderPurchase, springPurchase, boughtOutPartsPurchase,
        automationPartsPurchase, assemblyActuator, painting,
        finalAssembly, quality, packing, dispatch
    ) VALUES (UUID(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

    foreach ($data as $row) {
        $stmt->execute($row);
    }
}

// convertToCamelCase is defined at the top of this file.
