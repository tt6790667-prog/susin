import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sizing_page.dart';
import 'pds_sizing_page.dart';
import 'hd_sizing_page.dart';

class SizingHubPage extends StatelessWidget {
  const SizingHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
        title: Text(
          "SIZING UTILITIES",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: const Color(0xFF1E293B),
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Sizing Modules",
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Select the appropriate actuator thrust or torque sizing module.",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              
              // 1. Spring Actuator Card
              _buildSizingCard(
                context,
                title: "Spring Actuator Sizing",
                subtitle: "PLD & PLS Series (Linear Cylinder)",
                description: "Compute linear piston cylinder thrust outputs for double-acting and spring-return actuators.",
                icon: Icons.straighten_rounded,
                color: const Color(0xFFB71C1C), // SUSIN Red instead of blue
                targetPage: const SizingPage(),
              ),
              const SizedBox(height: 16),

              // 2. PDS Torque Sizing Card
              _buildSizingCard(
                context,
                title: "PDS Torque Sizing",
                subtitle: "PD & PS Series (Rack & Pinion)",
                description: "Size rack & pinion actuators against required valve torque with high-performance curve matching.",
                icon: Icons.rotate_right_rounded,
                color: const Color(0xFFB71C1C), // SUSIN Red
                targetPage: const PdsSizingPage(),
              ),
              const SizedBox(height: 16),

              // 3. HD Torque Sizing Card
              _buildSizingCard(
                context,
                title: "HD Torque Sizing",
                subtitle: "Heavy Duty Actuators (Scotch Yoke)",
                description: "Heavy-duty actuator sizing incorporating complex multi-stage pressure and spring curve interpolation.",
                icon: Icons.settings_input_component_rounded,
                color: const Color(0xFFB71C1C), // SUSIN Red
                targetPage: const HdSizingPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSizingCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required Color color,
    required Widget targetPage,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => targetPage),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12), // Clean moderate corners matching reference dashboard
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1), // Thin slate gray border from reference image
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      color: color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
            ),
          ],
        ),
      ),
    );
  }
}
