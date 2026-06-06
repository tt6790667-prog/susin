import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tickets_page.dart';

const _supportEmail = 'datasupport@susin.in';

/// Support + Tickets merged into one bottom-nav tab.
class SupportHubPage extends StatefulWidget {
  const SupportHubPage({super.key});

  @override
  State<SupportHubPage> createState() => _SupportHubPageState();
}

class _SupportHubPageState extends State<SupportHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _ticketsKey = GlobalKey<TicketsListTabState>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _open(Uri uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
    try {
      await launchUrl(uri, mode: mode);
    } catch (_) {}
  }

  /// Opens default mail app (Outlook, etc.) with To = datasupport@susin.in
  Future<void> _openEmailSupport() async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('Susin App Support')}',
    );

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      if (opened) return;
      await launchUrl(uri, mode: LaunchMode.platformDefault, webOnlyWindowName: '_self');
      return;
    } catch (_) {}

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open mail app. Email: $_supportEmail'),
        action: SnackBarAction(
          label: 'Copy',
          onPressed: () {
            Clipboard.setData(const ClipboardData(text: _supportEmail));
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          "Support",
          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFFB71C1C),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFB71C1C),
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: "Help"),
            Tab(text: "Tickets"),
          ],
        ),
        actions: [
          if (_tabs.index == 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _ticketsKey.currentState?.fetchTickets(),
            ),
        ],
      ),
      floatingActionButton: _tabs.index == 1
          ? FloatingActionButton.extended(
              onPressed: () => _ticketsKey.currentState?.showCreateDialog(),
              backgroundColor: const Color(0xFFB71C1C),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                'New ticket',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildHelpTab(),
          TicketsListTab(key: _ticketsKey),
        ],
      ),
    );
  }

  Widget _buildHelpTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          "Need help with orders, documents, or sizing?",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        const SizedBox(height: 20),
        _supportTile(
          icon: Icons.email_outlined,
          color: const Color(0xFF00897B),
          title: "Email Support",
          subtitle: _supportEmail,
          onTap: _openEmailSupport,
        ),
        const SizedBox(height: 12),
        _supportTile(
          icon: Icons.confirmation_number_outlined,
          color: const Color(0xFF5E35B1),
          title: "My Tickets",
          subtitle: "Switch to Tickets tab above",
          onTap: () => _tabs.animateTo(1),
        ),
        const SizedBox(height: 12),
        _supportTile(
          icon: Icons.language_rounded,
          color: const Color(0xFFB71C1C),
          title: "Visit Website",
          subtitle: "susingroup.com",
          onTap: () => _open(
            Uri.parse('https://susingroup.com'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }

  Widget _supportTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: title == 'Email Support'
                            ? const Color(0xFF00897B)
                            : Colors.grey.shade600,
                        fontSize: 12,
                        decoration: title == 'Email Support'
                            ? TextDecoration.underline
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
