import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sizing_data.dart';

class SizingPage extends StatefulWidget {
  const SizingPage({super.key});

  @override
  State<SizingPage> createState() => _SizingPageState();
}

class _SizingPageState extends State<SizingPage> {
  String _type = 'PLD'; // PLD (Double Acting) or PLS (Spring Return)
  int _size = 100;
  double _pressure = 4.2;
  double _strokeMm = 100.0;
  double _valveThrust = 0.0;
  String _failAction = 'FC';
  String _strokeAdj = 'full';

  late TextEditingController _thrustController;
  late TextEditingController _pressureController;
  late TextEditingController _strokeController;

  @override
  void initState() {
    super.initState();
    _thrustController = TextEditingController(text: '');
    _pressureController = TextEditingController(text: _pressure.toStringAsFixed(1));
    _strokeController = TextEditingController(text: _strokeMm.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _thrustController.dispose();
    _pressureController.dispose();
    _strokeController.dispose();
    super.dispose();
  }

  void _recalculateBestSize() {
    if (_valveThrust <= 0) {
      setState(() {
        _size = 100;
      });
      return;
    }

    int? bestSize;
    double bestSf = 9999;
    double targetSf = _type == 'PLD' ? 1.3 : 1.5;

    for (var size in modelSizes) {
      final pair = getModelPair(size);
      final pld = pair['pld'];
      final pls = pair['pls'];
      if (pld == null || pls == null) continue;

      double sf = 0.0;
      if (_type == 'PLD') {
        final pldCloseN = (_pressure / 10) * pld.pistonArea * pld.efficiency;
        final pldOpenN = (_pressure / 10) * pld.pRodArea * pld.efficiency;
        final activeForceN = _failAction == 'FC' ? pldCloseN : pldOpenN;
        sf = activeForceN / _valveThrust;
      } else {
        final cylinderForceN = (_pressure / 10) * pls.pistonArea * pls.efficiency;
        final springStartN = cylinderForceN * 0.35;
        final springEndN = cylinderForceN * 0.70;

        if (_failAction == 'FC') {
          final plsSpringCloseN = springStartN;
          final plsAirOpenEndN = cylinderForceN - springEndN;
          sf = min(plsSpringCloseN / _valveThrust, plsAirOpenEndN / _valveThrust);
        } else {
          final plsSpringOpenN = springStartN;
          final plsAirCloseEndN = cylinderForceN - springEndN;
          sf = min(plsSpringOpenN / _valveThrust, plsAirCloseEndN / _valveThrust);
        }
      }

      if (sf >= targetSf && sf < bestSf) {
        bestSf = sf;
        bestSize = size;
      }
    }

    setState(() {
      if (bestSize != null) {
        _size = bestSize;
      } else {
        _size = modelSizes.last;
      }
    });
  }

  Map<String, dynamic>? get _results {
    final pair = getModelPair(_size);
    final pld = pair['pld'];
    final pls = pair['pls'];
    if (pld == null || pls == null) return null;

    // ── PLD Calculations ───────────────────────────────────
    final pldCloseN = (_pressure / 10) * pld.pistonArea * pld.efficiency;
    final pldOpenN = (_pressure / 10) * pld.pRodArea * pld.efficiency;
    
    final pldCloseKN = pldCloseN / 1000;
    final pldOpenKN = pldOpenN / 1000;

    // ── PLS Calculations ───────────────────────────────────
    double strokeMm = _strokeMm;
    if (_strokeAdj == '50%') strokeMm *= 0.5;

    final cylinderForceN = (_pressure / 10) * pls.pistonArea * pls.efficiency;
    final springStartN = cylinderForceN * 0.35;
    final springEndN = cylinderForceN * 0.70;
    
    double plsSpringOpenN = 0, plsSpringCloseN = 0;
    double plsAirOpenStartN = 0, plsAirOpenEndN = 0;
    double plsAirCloseStartN = 0, plsAirCloseEndN = 0;

    if (_failAction == 'FC') {
      plsSpringOpenN = springEndN;
      plsSpringCloseN = springStartN;
      plsAirOpenStartN = cylinderForceN - springStartN;
      plsAirOpenEndN = cylinderForceN - springEndN;
    } else {
      plsSpringOpenN = springStartN;
      plsSpringCloseN = springEndN;
      plsAirCloseStartN = cylinderForceN - springStartN;
      plsAirCloseEndN = cylinderForceN - springEndN;
    }

    final plsSpringOpenKN = plsSpringOpenN / 1000;
    final plsSpringCloseKN = plsSpringCloseN / 1000;
    final plsAirOpenStartKN = plsAirOpenStartN / 1000;
    final plsAirOpenEndKN = plsAirOpenEndN / 1000;
    final plsAirCloseStartKN = plsAirCloseStartN / 1000;
    final plsAirCloseEndKN = plsAirCloseEndN / 1000;

    final strokeM = strokeMm / 1000;
    final computedSpringRate = strokeM > 0 ? (springEndN - springStartN) / 1000 / strokeM : 0.0;

    // ── Safety Factor Calculation ──────────────────────────
    double safetyFactor = 0.0;
    if (_valveThrust > 0) {
      if (_type == 'PLD') {
        final activeForceN = _failAction == 'FC' ? pldCloseN : pldOpenN;
        safetyFactor = activeForceN / _valveThrust;
      } else {
        if (_failAction == 'FC') {
          final sfClose = plsSpringCloseN / _valveThrust;
          final sfOpen = plsAirOpenEndN / _valveThrust;
          safetyFactor = min(sfClose, sfOpen);
        } else {
          final sfOpen = plsSpringOpenN / _valveThrust;
          final sfClose = plsAirCloseEndN / _valveThrust;
          safetyFactor = min(sfClose, sfOpen);
        }
      }
    }

    return {
      'pldCloseN': pldCloseN.toStringAsFixed(0),
      'pldOpenN': pldOpenN.toStringAsFixed(0),
      'pldCloseKN': pldCloseKN.toStringAsFixed(2),
      'pldOpenKN': pldOpenKN.toStringAsFixed(2),
      
      'plsSpringOpenN': plsSpringOpenN.toStringAsFixed(0),
      'plsSpringCloseN': plsSpringCloseN.toStringAsFixed(0),
      'plsSpringOpenKN': plsSpringOpenKN.toStringAsFixed(2),
      'plsSpringCloseKN': plsSpringCloseKN.toStringAsFixed(2),
      
      'plsAirOpenStartN': plsAirOpenStartN.toStringAsFixed(0),
      'plsAirOpenEndN': plsAirOpenEndN.toStringAsFixed(0),
      'plsAirOpenStartKN': plsAirOpenStartKN.toStringAsFixed(2),
      'plsAirOpenEndKN': plsAirOpenEndKN.toStringAsFixed(2),
      
      'plsAirCloseStartN': plsAirCloseStartN.toStringAsFixed(0),
      'plsAirCloseEndN': plsAirCloseEndN.toStringAsFixed(0),
      'plsAirCloseStartKN': plsAirCloseStartKN.toStringAsFixed(2),
      'plsAirCloseEndKN': plsAirCloseEndKN.toStringAsFixed(2),
      
      'adjStrokeMm': strokeMm.toStringAsFixed(0),
      'calcSpringRate': computedSpringRate.toStringAsFixed(2),
      'boreDia': pld.boreDia.toString(),
      'pistonArea': pld.pistonArea.toStringAsFixed(1),
      'pldRemarks': pld.remarks,
      'plsRemarks': pls.remarks,
      'safetyFactor': safetyFactor,
    };
  }

  @override
  Widget build(BuildContext context) {
    final res = _results;
    final isPLD = _type == 'PLD';

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
        leading: Padding(
          padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10),
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFF475569)),
            ),
          ),
        ),
        title: Text(
          "Spring Actuator Sizing",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: const Color(0xFF1E293B),
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: res == null
            ? const Center(child: Text("Select a model to begin."))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pill selector for PLD / PLS
                    _buildTypeSelector(),
                    const SizedBox(height: 24),

                    // Inputs Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB71C1C).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.tune_rounded, color: Color(0xFFB71C1C), size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "INPUT PARAMETERS",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1E293B),
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Valve Thrust Input Field (N)
                          Text("VALVE THRUST REQ (N)", style: _labelStyle()),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _thrustController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B)),
                            decoration: _inputDecoration("Enter required thrust (N)"),
                            onChanged: (v) {
                              _valveThrust = double.tryParse(v) ?? 0.0;
                              _recalculateBestSize();
                            },
                          ),
                          const SizedBox(height: 20),

                          // Input Pressure Supply (Bar)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("INPUT PRESSURE SUPPLY (BAR)", style: _labelStyle()),
                              Text(
                                "${_pressure.toStringAsFixed(1)} bar",
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFB71C1C)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _pressureController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B)),
                            decoration: _inputDecoration("Enter pressure (bar)"),
                            onChanged: (v) {
                              final p = double.tryParse(v);
                              if (p != null) {
                                _pressure = p.clamp(1.0, 10.0);
                                _recalculateBestSize();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFB71C1C),
                              inactiveTrackColor: const Color(0xFFF1F5F9),
                              thumbColor: const Color(0xFFB71C1C),
                              overlayColor: const Color(0xFFB71C1C).withOpacity(0.1),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _pressure.clamp(1.0, 10.0),
                              min: 1.0,
                              max: 10.0,
                              divisions: 90,
                              onChanged: (v) {
                                _pressure = v;
                                _pressureController.text = v.toStringAsFixed(1);
                                _recalculateBestSize();
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Stroke Length Required (mm)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("STROKE LENGTH REQUIRED (MM)", style: _labelStyle()),
                              Text(
                                "${_strokeMm.toStringAsFixed(0)} mm",
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFB71C1C)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _strokeController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: const Color(0xFF1E293B)),
                            decoration: _inputDecoration("Enter stroke length (mm)"),
                            onChanged: (v) {
                              final s = double.tryParse(v);
                              if (s != null) {
                                _strokeMm = s.clamp(10.0, 1000.0);
                                _recalculateBestSize();
                              }
                            },
                          ),
                          const SizedBox(height: 8),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: const Color(0xFFB71C1C),
                              inactiveTrackColor: const Color(0xFFF1F5F9),
                              thumbColor: const Color(0xFFB71C1C),
                              overlayColor: const Color(0xFFB71C1C).withOpacity(0.1),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              trackHeight: 3,
                            ),
                            child: Slider(
                              value: _strokeMm.clamp(10.0, 1000.0),
                              min: 10.0,
                              max: 1000.0,
                              divisions: 99,
                              onChanged: (v) {
                                _strokeMm = v;
                                _strokeController.text = v.toStringAsFixed(0);
                                _recalculateBestSize();
                              },
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Fail Action
                          Text("Fail Action", style: _labelStyle()),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _segmentBtn("Fail Close (FC)", _failAction == 'FC', () {
                                  _failAction = 'FC';
                                  _recalculateBestSize();
                                }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _segmentBtn("Fail Open (FO)", _failAction == 'FO', () {
                                  _failAction = 'FO';
                                  _recalculateBestSize();
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Stroke Adj.
                          Text("Stroke Adj.", style: _labelStyle()),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _segmentBtn("Full", _strokeAdj == 'full', () {
                                  _strokeAdj = 'full';
                                  _recalculateBestSize();
                                }),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _segmentBtn("50%", _strokeAdj == '50%', () {
                                  _strokeAdj = '50%';
                                  _recalculateBestSize();
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Outputs
                    if (isPLD) ...[
                      // PLD Outputs
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFB71C1C).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "PLD-$_size",
                                    style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 11, color: const Color(0xFFB71C1C)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text("— Air Thrust Output", style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 14, color: const Color(0xFF1E293B))),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Double Acting · Bore ${res['boreDia']} mm · Area ${res['pistonArea']} mm²", style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("CLOSE THRUST", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      Text("${res['pldCloseKN']} KN", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                                      Text("${res['pldCloseN']} N", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 48, color: const Color(0xFFE2E8F0)),
                                const SizedBox(width: 24),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("OPEN THRUST", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 0.5)),
                                      const SizedBox(height: 4),
                                      Text("${res['pldOpenKN']} KN", style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                                      Text("${res['pldOpenN']} N", style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // PLS Outputs
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("PLS-$_size — Spring Output", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF1E293B))),
                                  const SizedBox(height: 4),
                                  Text("Bore ${res['boreDia']} mm · Area ${res['pistonArea']} mm²", style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 16),
                                  Text("OPEN (Compressed)", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text("${res['plsSpringOpenKN']} KN", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFB71C1C))),
                                  Text("${res['plsSpringOpenN']} N", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                  const SizedBox(height: 12),
                                  Text("CLOSE (Extended)", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                                  const SizedBox(height: 2),
                                  Text("${res['plsSpringCloseKN']} KN", style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFB71C1C))),
                                  Text("${res['plsSpringCloseN']} N", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("PLS-$_size — Net Air", style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 12, color: const Color(0xFF1E293B))),
                                  const SizedBox(height: 16),
                                  if (_failAction == 'FC') ...[
                                    Text("AIR OPEN (START -> END)", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text("${res['plsAirOpenStartKN']} -> ${res['plsAirOpenEndKN']} KN", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                                    Text("${res['plsAirOpenStartN']} -> ${res['plsAirOpenEndN']} N", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 12),
                                    Text("AIR CLOSE", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text("Vented - Spring Closes", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                  ] else ...[
                                    Text("AIR OPEN", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text("Vented - Spring Opens", style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 12),
                                    Text("AIR CLOSE (START -> END)", style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text("${res['plsAirCloseStartKN']} -> ${res['plsAirCloseEndKN']} KN", style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF1E293B))),
                                    Text("${res['plsAirCloseStartN']} -> ${res['plsAirCloseEndN']} N", style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
                                  ]
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Safety Factor Card
                    if (_valveThrust > 0) _buildSafetyFactorCard(res['safetyFactor']),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  TextStyle _labelStyle() => const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B));

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 1.5),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                _type = 'PLD';
                _recalculateBestSize();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'PLD' ? const Color(0xFFB71C1C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Double Acting (PLD)",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _type == 'PLD' ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                _type = 'PLS';
                _recalculateBestSize();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _type == 'PLS' ? const Color(0xFFB71C1C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  "Spring Return (PLS)",
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: _type == 'PLS' ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segmentBtn(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFB71C1C) : const Color(0xFFF8FAFC),
          border: Border.all(color: isActive ? const Color(0xFFB71C1C) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: isActive ? Colors.white : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildSafetyFactorCard(double safetyFactor) {
    final isPLD = _type == 'PLD';
    final greenThreshold = isPLD ? 1.3 : 1.5;
    final yellowThreshold = isPLD ? 1.15 : 1.25;

    Color cardBg = safetyFactor >= greenThreshold 
        ? const Color(0xFFE2F0D9) 
        : (safetyFactor >= yellowThreshold ? const Color(0xFFFFF2CC) : const Color(0xFFFCE4D6));
    Color borderCol = safetyFactor >= greenThreshold 
        ? const Color(0xFFA9D08E) 
        : (safetyFactor >= yellowThreshold ? const Color(0xFFFFD966) : const Color(0xFFF4B084));
    Color textCol = safetyFactor >= greenThreshold 
        ? const Color(0xFF385723) 
        : (safetyFactor >= yellowThreshold ? const Color(0xFF7F6000) : const Color(0xFFC65911));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "SAFETY FACTOR",
                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: textCol, letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                safetyFactor >= greenThreshold 
                    ? "OPTIMIZED SIZING" 
                    : (safetyFactor >= yellowThreshold ? "MARGINAL WARNING" : "UNDERSIZED DANGER"),
                style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: textCol),
              ),
            ],
          ),
          Text(
            safetyFactor.toStringAsFixed(2),
            style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: textCol),
          ),
        ],
      ),
    );
  }
}
