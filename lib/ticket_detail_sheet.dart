import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_config.dart';

/// Full ticket details — draggable sheet, one scroll, image preview capped.
class TicketDetailSheet {
  static Future<void> show(BuildContext context, Map<String, dynamic> ticket) {
    final wide = MediaQuery.sizeOf(context).width >= 700;
    if (wide) {
      return showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
            ),
            child: _TicketDetailBody(ticket: ticket, scrollController: null),
          ),
        ),
      );
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (_, scrollController) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: _TicketDetailBody(
            ticket: ticket,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }
}

class _TicketDetailBody extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final ScrollController? scrollController;

  const _TicketDetailBody({required this.ticket, this.scrollController});

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      var s = raw.trim();
      if (s.endsWith('Z')) {
        s = '${s.substring(0, s.length - 1)}+00:00';
      }
      return DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.parse(s).toLocal());
    } catch (_) {
      return raw;
    }
  }

  String _priorityLabel(String? p) {
    if (p == null || p.isEmpty) return 'Medium';
    final lower = p.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  Color _priorityColor(String? p) {
    switch ((p ?? 'medium').toLowerCase()) {
      case 'urgent':
        return const Color(0xFFB71C1C);
      case 'high':
        return const Color(0xFFE65100);
      case 'low':
        return const Color(0xFF546E7A);
      default:
        return const Color(0xFFB71C1C);
    }
  }

  Color _statusColor(String? s) {
    switch ((s ?? 'open').toLowerCase()) {
      case 'resolved':
        return const Color(0xFF546E7A);
      case 'in-progress':
        return const Color(0xFFF4511E);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  static String resolveAttachmentUrl(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http')) {
      if (raw.contains('/uploads/') && !raw.contains('/support-api/')) {
        final origin = Uri.parse(raw).origin;
        final tail = raw.split('/uploads/').last;
        return '$origin/support-api/uploads/$tail';
      }
      return raw;
    }
    final base = ApiConfig.supportApiBase.replaceAll('/api', '');
    return '$base/${raw.startsWith('/') ? raw.substring(1) : raw}';
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  void _openFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(ctx).top + 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _infoLine(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.black87, height: 1.35),
            ),
          ),
          if (copyable)
            IconButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              icon: const Icon(Icons.copy, size: 18),
              color: Colors.grey.shade600,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ],
      ),
    );
  }

  Widget _attachmentSection(BuildContext context, String url) {
    final isImage = _isImageUrl(url);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Attachment (Evidence)',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const Spacer(),
            if (isImage)
              TextButton.icon(
                onPressed: () => _openFullImage(context, url),
                icon: const Icon(Icons.fullscreen, size: 18),
                label: const Text('Full screen'),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFB71C1C)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (isImage)
          GestureDetector(
            onTap: () => _openFullImage(context, url),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                color: Colors.grey.shade50,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      height: 200,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(color: Color(0xFFB71C1C)),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => _fileCard(url),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        Icon(Icons.touch_app_outlined, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'Tap for full image',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          _fileCard(url),
      ],
    );
  }

  Widget _fileCard(String url) {
    return Material(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file_outlined, color: Color(0xFFB71C1C)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  url.split('/').last,
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.open_in_new, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subject = ticket['subject']?.toString() ?? 'Ticket';
    final description = ticket['description']?.toString() ?? '';
    final status = (ticket['status'] ?? 'open').toString();
    final priority = ticket['priority']?.toString();
    final userName = (ticket['userName'] ?? 'App User').toString();
    final userEmail = ticket['userEmail']?.toString() ?? '';
    final attachmentRaw = ticket['attachment']?.toString() ?? '';
    final attachment = resolveAttachmentUrl(attachmentRaw);
    final id = ticket['id']?.toString() ?? '';
    final bottomPad = MediaQuery.paddingOf(context).bottom + 40;

    return ListView(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPad),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                subject,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  height: 1.25,
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _chip(status, _statusColor(status)),
            _chip(_priorityLabel(priority), _priorityColor(priority)),
            if (attachment.isNotEmpty) _chip('Has attachment', const Color(0xFF5E35B1)),
          ],
        ),
        const SizedBox(height: 18),
        _infoCard([
          _infoLine('Submitted by', userName),
          if (userEmail.isNotEmpty) _infoLine('Email', userEmail),
          _infoLine('Created', _formatDate(ticket['createdAt']?.toString())),
          if (ticket['updatedAt'] != null)
            _infoLine('Updated', _formatDate(ticket['updatedAt']?.toString())),
          if (id.isNotEmpty) _infoLine('Ticket ID', id, copyable: true),
        ]),
        const SizedBox(height: 16),
        Text(
          'Description',
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: SelectableText(
            description.isEmpty ? '—' : description,
            style: GoogleFonts.inter(fontSize: 14, color: Colors.black87, height: 1.55),
          ),
        ),
        if (attachment.isNotEmpty) ...[
          const SizedBox(height: 20),
          _attachmentSection(context, attachment),
        ],
        const SizedBox(height: 8),
        Text(
          'Drag up or scroll to see all details',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}
