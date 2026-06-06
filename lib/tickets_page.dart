import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'create_ticket_sheet.dart';
import 'ticket_detail_sheet.dart';
import 'api_config.dart';

/// Tickets list body (used inside Support hub tab).
class TicketsListTab extends StatefulWidget {
  const TicketsListTab({super.key});

  @override
  State<TicketsListTab> createState() => TicketsListTabState();
}

class TicketsListTabState extends State<TicketsListTab> {
  List<dynamic> _tickets = [];
  List<dynamic> _filtered = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  int? _selectedIndex;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    final q = _searchQuery.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_tickets)
          : _tickets.where((t) {
              final subject = (t['subject'] ?? '').toString().toLowerCase();
              final user = (t['userName'] ?? '').toString().toLowerCase();
              final status = (t['status'] ?? '').toString().toLowerCase();
              return subject.contains(q) || user.contains(q) || status.contains(q);
            }).toList();
      if (_selectedIndex != null && _selectedIndex! >= _filtered.length) {
        _selectedIndex = null;
      }
    });
  }

  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('access_token')?.trim();
    if (t == null || t.isEmpty || t == 'null') return null;
    return t.startsWith('Bearer ') ? t.substring(7).trim() : t;
  }

  // Retrieve stored region id for current user
  Future<String?> _selectedRegionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_region');
  }

  Future<void> fetchTickets() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = "Please log in again.";
        });
        return;
      }
      // Include region filter if set
      final regionId = await _selectedRegionId();
      String url = ApiConfig.ticketsUrl;
      if (regionId != null && regionId.isNotEmpty) {
        url += '?regionId=' + Uri.encodeComponent(regionId);
      }
      final res = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      final body = res.body.trim();
      if (res.statusCode == 200) {
        if (!body.startsWith('[') && !body.startsWith('{')) {
          setState(() {
            _isLoading = false;
            _error =
                'Tickets API not found on server (got HTML, not JSON).\n\n'
                'Expected: ${ApiConfig.supportApiBase}/health.php\n'
                'Upload support-api/api → public_html/support-api/api/';
          });
          return;
        }
        final data = json.decode(body);
        setState(() {
          _tickets = data is List ? data : [];
          _isLoading = false;
        });
        _applyFilter();
      } else if (res.statusCode == 401) {
        setState(() {
          _isLoading = false;
          _error = 'Session expired or no SUPPORT access in Central Users.';
        });
      } else {
        String detail = body;
        try {
          final j = json.decode(body);
          if (j is Map && j['message'] != null) {
            detail = j['message'].toString();
          }
        } catch (_) {}
        setState(() {
          _isLoading = false;
          _error = 'Could not load tickets (${res.statusCode})\n$detail';
        });
      }
    } catch (e) {
      final msg = e.toString();
      String hint = '';
      if (msg.contains('Failed to fetch') ||
          msg.contains('ERR_NAME_NOT_RESOLVED') ||
          msg.contains('getaddrinfo')) {
        hint =
            '\n\nTickets API: ${ApiConfig.supportApiBase}/\n'
            'Path: app.susingroup.com/support-api/api/\n'
            'Test: ${ApiConfig.supportApiBase}/health.php → {"ok":true}';
      }
      setState(() {
        _isLoading = false;
        _error = 'Network error: $e$hint';
      });
    }
  }

  Future<void> showCreateDialog() async {
    final token = await _token();
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again.')),
        );
      }
      return;
    }
    if (!mounted) return;
    await CreateTicketSheet.show(
      context,
      accessToken: token,
      onCreated: fetchTickets,
    );
  }

  Color _statusDotColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.grey.shade400;
      case 'in-progress':
        return const Color(0xFFF4511E);
      default:
        return const Color(0xFF43A047);
    }
  }

  bool _isHighPriority(String? priority) {
    final p = (priority ?? '').toLowerCase();
    return p == 'high' || p == 'urgent';
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      return DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  String _sourceLabel(dynamic t) {
    final name = (t['userName'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;
    return 'Susin Support';
  }

  void _showTicketDetail(dynamic t) {
    TicketDetailSheet.show(context, Map<String, dynamic>.from(t as Map));
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          _searchQuery = v;
          _applyFilter();
        },
        decoration: InputDecoration(
          hintText: 'Search tickets...',
          prefixIcon: const Icon(Icons.search, size: 22),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  String _priorityShort(String? p) {
    if (p == null || p.isEmpty) return 'Med';
    final s = p.toLowerCase();
    if (s == 'urgent') return 'Urgent';
    if (s == 'high') return 'High';
    if (s == 'low') return 'Low';
    return 'Med';
  }

  Color _priorityBadgeColor(String? p) {
    switch ((p ?? 'medium').toLowerCase()) {
      case 'urgent':
        return const Color(0xFFB71C1C);
      case 'high':
        return const Color(0xFFE65100);
      case 'low':
        return const Color(0xFF546E7A);
      default:
        return const Color(0xFF1565C0);
    }
  }

  bool _hasAttachment(dynamic t) {
    final a = t['attachment']?.toString() ?? '';
    return a.isNotEmpty;
  }

  Widget _buildTicketRow(dynamic t, int index, {required bool isLast}) {
    final status = (t['status'] ?? 'open').toString();
    final priority = t['priority']?.toString();
    final isSelected = _selectedIndex == index;
    final desc = (t['description'] ?? '').toString();

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedIndex = index);
          _showTicketDetail(t);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, isSelected ? 14 : 12, 12, isSelected ? 14 : 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['subject']?.toString() ?? 'No subject',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                        height: 1.25,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        desc,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      _sourceLabel(t),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatDate(t['createdAt']?.toString()),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _priorityBadgeColor(priority).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _priorityShort(priority),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: _priorityBadgeColor(priority),
                            ),
                          ),
                        ),
                        if (_hasAttachment(t)) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.image_outlined,
                              size: 14, color: Colors.grey.shade500),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _statusDotColor(status),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Icon(
                    _isHighPriority(priority)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 22,
                    color: _isHighPriority(priority)
                        ? const Color(0xFFB71C1C)
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (isSelected) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: content,
      );
    }

    return Column(
      children: [
        content,
        if (!isLast)
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200, indent: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFB71C1C)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(onPressed: fetchTickets, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty
                        ? "No tickets match your search"
                        : "No tickets yet.\nTap + to create one.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : RefreshIndicator(
                  color: const Color(0xFFB71C1C),
                  onRefresh: fetchTickets,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _filtered.length,
                    itemBuilder: (context, i) {
                      return _buildTicketRow(
                        _filtered[i],
                        i,
                        isLast: i == _filtered.length - 1,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
