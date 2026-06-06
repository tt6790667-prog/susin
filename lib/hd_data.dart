// HD Actuator Data Structure
// Data extracted from the Catalog Sheets

const Map<String, Map<String, List<double>>> hdDoubleActing = {
  // Format: 'MODEL': {'3.5': [Start, Run, End], '4.2': [Start, Run, End], ...}
  'ISD-A1-10': {
    '3.5': [140, 84, 132],
    '4.2': [168, 100, 158],
    '5.5': [221, 132, 207],
    '7.0': [281, 167, 263],
  },
  'ISD-01-10': {
    '3.5': [240, 143, 225],
    '4.2': [288, 172, 270],
    '5.5': [377, 225, 354],
    '7.0': [480, 286, 450],
  },
  'ISD-06-88': {
    '3.5': [57199, 34203, 56887],
    '4.2': [68639, 43443, 68265],
    '5.5': [89885, 56890, 89394],
    '7.0': [114399, 72406, 113775],
  },
  'ICD-A1-10': {
    '3.5': [170, 84, 113],
    '4.2': [201, 100, 135],
    '5.5': [263, 132, 177],
    '7.0': [335, 167, 225],
  },
};

const Map<String, Map<String, List<double>>> hdSingleActing = {
  // Format: 'MODEL': {'spring': [Start, Run, End], '3.5': [Start, Run, End], ...}
  'ISR-A1-12': {
    'spring': [136, 69, 83],
    '3.5': [143, 69, 82],
    '4.2': [189, 97, 125],
    '5.5': [273, 148, 206],
    '7.0': [370, 208, 300],
  },
  'ICR-01-12': {
    'spring': [202, 116, 169],
    '3.5': [300, 121, 117],
    '4.2': [394, 169, 181],
    '5.5': [568, 257, 300],
    '7.0': [768, 358, 437],
  },
};

List<double> interpolateHD(Map<String, List<double>> data, double pressure, bool isSpring) {
  if (isSpring && data.containsKey('spring')) {
    return data['spring']!;
  }
  
  final List<double> pressures = [3.5, 4.2, 5.5, 7.0];
  
  if (pressure <= 3.5) return data['3.5']!;
  if (pressure >= 7.0) return data['7.0']!;
  
  for (int i = 0; i < pressures.length - 1; i++) {
    if (pressure >= pressures[i] && pressure <= pressures[i + 1]) {
      double p1 = pressures[i];
      double p2 = pressures[i + 1];
      
      List<double> v1 = data[p1.toString()] ?? [0,0,0];
      List<double> v2 = data[p2.toString()] ?? [0,0,0];
      
      double factor = (pressure - p1) / (p2 - p1);
      
      return [
        v1[0] + (v2[0] - v1[0]) * factor,
        v1[1] + (v2[1] - v1[1]) * factor,
        v1[2] + (v2[2] - v1[2]) * factor,
      ];
    }
  }
  
  return data['5.5'] ?? [0,0,0];
}
