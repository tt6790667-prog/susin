import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_config.dart';
import 'main.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegionSelectPage extends StatefulWidget {
  const RegionSelectPage({super.key});

  @override
  State<RegionSelectPage> createState() => _RegionSelectPageState();
}

class _RegionSelectPageState extends State<RegionSelectPage> {
  List<dynamic> _regions = [];
  String? _selectedId;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.get(Uri.parse(ApiConfig.regionsUrl)).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is List) {
          setState(() {
            _regions = data;
            _loading = false;
          });
        } else {
          setState(() {
            _error = 'Unexpected response format';
            _loading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to load regions (${res.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading regions: $e';
        _loading = false;
      });
    }
  }

  Future<void> _saveAndProceed() async {
    if (_selectedId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_region', _selectedId!);
    // Navigate to Login Page after selecting region
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Select Region', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        leading: const BackButton(color: Colors.black),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Region',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: _regions.map<DropdownMenuItem<String>>((region) {
                            final id = region['id']?.toString() ?? '';
                            final name = region['name']?.toString() ?? id;
                            return DropdownMenuItem(value: id, child: Text(name));
                          }).toList(),
                          value: _selectedId,
                          onChanged: (val) => setState(() => _selectedId = val),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _selectedId == null ? null : _saveAndProceed,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C)),
                          child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
