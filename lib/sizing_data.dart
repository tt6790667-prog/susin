class ActuatorModel {
  final String model;
  final String type; // 'PLD' | 'PLS'
  final double efficiency;
  final int cylModel;
  final double boreDia;
  final double pistonArea;
  final double pRodDia;
  final double pRodArea;
  final double? strokeMm;
  final double? l1Mm;
  final double? l2Mm;
  final String remarks;

  const ActuatorModel({
    required this.model,
    required this.type,
    required this.efficiency,
    required this.cylModel,
    required this.boreDia,
    required this.pistonArea,
    required this.pRodDia,
    required this.pRodArea,
    this.strokeMm,
    this.l1Mm,
    this.l2Mm,
    required this.remarks,
  });
}

const List<ActuatorModel> actuatorModels = [
  ActuatorModel(model: 'PLD-100', type: 'PLD', efficiency: 0.95, cylModel: 10, boreDia: 100, pistonArea: 7850, pRodDia: 25, pRodArea: 7359.38, remarks: 'Range from 2 KN to 5 KN'),
  ActuatorModel(model: 'PLS-100', type: 'PLS', efficiency: 0.95, cylModel: 10, boreDia: 100, pistonArea: 7850, pRodDia: 25, pRodArea: 7359.38, strokeMm: 50, l1Mm: 25, l2Mm: 75, remarks: 'PLS- 0.8 KN to 2 KN'),
  ActuatorModel(model: 'PLD-125', type: 'PLD', efficiency: 0.95, cylModel: 12, boreDia: 127, pistonArea: 12661.27, pRodDia: 25, pRodArea: 12170.64, remarks: 'Range from 3 KN to 8 KN'),
  ActuatorModel(model: 'PLS-125', type: 'PLS', efficiency: 0.95, cylModel: 12, boreDia: 127, pistonArea: 12661.27, pRodDia: 25, pRodArea: 12170.64, remarks: 'PLS- 1.3 KN to 3.2 KN'),
  ActuatorModel(model: 'PLD-160', type: 'PLD', efficiency: 0.95, cylModel: 16, boreDia: 160, pistonArea: 20096, pRodDia: 25, pRodArea: 19605.38, remarks: 'Range from 5 KN to 13 KN'),
  ActuatorModel(model: 'PLS-160', type: 'PLS', efficiency: 0.95, cylModel: 16, boreDia: 160, pistonArea: 20096, pRodDia: 25, pRodArea: 19605.38, remarks: 'PLS- 2.1 KN to 5.2 KN'),
  ActuatorModel(model: 'PLD-180', type: 'PLD', efficiency: 0.95, cylModel: 17, boreDia: 180, pistonArea: 25434, pRodDia: 25, pRodArea: 24943.38, remarks: 'Range from 6.5 KN to 17 KN'),
  ActuatorModel(model: 'PLS-180', type: 'PLS', efficiency: 0.95, cylModel: 17, boreDia: 180, pistonArea: 25434, pRodDia: 25, pRodArea: 24943.38, remarks: 'PLS- 2.7 KN to 6.6 KN'),
  ActuatorModel(model: 'PLD-200', type: 'PLD', efficiency: 0.95, cylModel: 20, boreDia: 200.5, pistonArea: 31557.2, pRodDia: 25, pRodArea: 31066.57, remarks: 'Range from 8 KN to 21 KN'),
  ActuatorModel(model: 'PLS-200', type: 'PLS', efficiency: 0.95, cylModel: 20, boreDia: 200.5, pistonArea: 31557.2, pRodDia: 25, pRodArea: 31066.57, remarks: 'PLS- 3.3 KN to 8.4 KN'),
  ActuatorModel(model: 'PLD-230', type: 'PLD', efficiency: 0.95, cylModel: 23, boreDia: 227, pistonArea: 40450.27, pRodDia: 32, pRodArea: 39646.43, remarks: 'Range from 10.5 KN to 27 KN'),
  ActuatorModel(model: 'PLS-230', type: 'PLS', efficiency: 0.95, cylModel: 23, boreDia: 227, pistonArea: 40450.27, pRodDia: 32, pRodArea: 39646.43, remarks: 'PLS- 4.3 KN to 10.5 KN'),
  ActuatorModel(model: 'PLD-250', type: 'PLD', efficiency: 0.95, cylModel: 25, boreDia: 249.8, pistonArea: 48984.03, pRodDia: 32, pRodArea: 48180.19, remarks: 'Range from 12.5 KN to 32 KN'),
  ActuatorModel(model: 'PLS-250', type: 'PLS', efficiency: 0.95, cylModel: 25, boreDia: 249.8, pistonArea: 48984.03, pRodDia: 32, pRodArea: 48180.19, remarks: 'PLS- 5.1 KN to 13 KN'),
  ActuatorModel(model: 'PLD-280', type: 'PLD', efficiency: 0.95, cylModel: 28, boreDia: 280, pistonArea: 61544, pRodDia: 32, pRodArea: 60740.16, remarks: 'Range from 16 KN to 40 KN'),
  ActuatorModel(model: 'PLS-280', type: 'PLS', efficiency: 0.95, cylModel: 28, boreDia: 280, pistonArea: 61544, pRodDia: 32, pRodArea: 60740.16, remarks: 'PLS- 6.5 KN to 16 KN'),
  ActuatorModel(model: 'PLD-300', type: 'PLD', efficiency: 0.95, cylModel: 30, boreDia: 304.8, pistonArea: 72928.89, pRodDia: 32, pRodArea: 72125.05, remarks: 'Range from 19 KN to 48.5 KN'),
  ActuatorModel(model: 'PLS-300', type: 'PLS', efficiency: 0.95, cylModel: 30, boreDia: 304.8, pistonArea: 72928.89, pRodDia: 32, pRodArea: 72125.05, remarks: 'PLS- 7.5 KN to 19 KN'),
  ActuatorModel(model: 'PLD-350', type: 'PLD', efficiency: 0.95, cylModel: 35, boreDia: 330.6, pistonArea: 85797.64, pRodDia: 32, pRodArea: 84993.8, remarks: 'Range from 22.5 KN to 57 KN'),
  ActuatorModel(model: 'PLS-350', type: 'PLS', efficiency: 0.95, cylModel: 35, boreDia: 330.6, pistonArea: 85797.64, pRodDia: 32, pRodArea: 84993.8, remarks: 'PLS- 9 KN to 22.5 KN'),
  ActuatorModel(model: 'PLD-380', type: 'PLD', efficiency: 0.95, cylModel: 38, boreDia: 388.7, pistonArea: 118603.84, pRodDia: 32, pRodArea: 117800, remarks: 'Range from 31 KN to 78 KN'),
  ActuatorModel(model: 'PLS-380', type: 'PLS', efficiency: 0.95, cylModel: 38, boreDia: 388.7, pistonArea: 118603.84, pRodDia: 32, pRodArea: 117800, remarks: 'PLS- 12.5 KN to 31.5 KN'),
  ActuatorModel(model: 'PLD-430', type: 'PLD', efficiency: 0.95, cylModel: 43, boreDia: 435.4, pistonArea: 148814.93, pRodDia: 42, pRodArea: 147430.19, remarks: 'Range from 39 KN to 99 KN'),
  ActuatorModel(model: 'PLS-430', type: 'PLS', efficiency: 0.95, cylModel: 43, boreDia: 435.4, pistonArea: 148814.93, pRodDia: 42, pRodArea: 147430.19, remarks: 'PLS- 15.5 KN to 39.5 KN'),
  ActuatorModel(model: 'PLD-480', type: 'PLD', efficiency: 0.95, cylModel: 48, boreDia: 482.7, pistonArea: 182904.44, pRodDia: 42, pRodArea: 181519.7, remarks: 'Range from 48 KN to 121 KN'),
  ActuatorModel(model: 'PLS-480', type: 'PLS', efficiency: 0.95, cylModel: 48, boreDia: 482.7, pistonArea: 182904.44, pRodDia: 42, pRodArea: 181519.7, remarks: 'PLS- 19.5 KN to 48.5 KN'),
  ActuatorModel(model: 'PLD-530', type: 'PLD', efficiency: 0.95, cylModel: 53, boreDia: 534.8, pistonArea: 224518.67, pRodDia: 42, pRodArea: 223133.93, remarks: 'Range from 59 KN to 149 KN'),
  ActuatorModel(model: 'PLS-530', type: 'PLS', efficiency: 0.95, cylModel: 53, boreDia: 534.8, pistonArea: 224518.67, pRodDia: 42, pRodArea: 223133.93, remarks: 'PLS- 23.5 KN to 59.5 KN'),
  ActuatorModel(model: 'PLD-580', type: 'PLD', efficiency: 0.95, cylModel: 58, boreDia: 591.6, pistonArea: 274742.59, pRodDia: 42, pRodArea: 273357.85, remarks: 'Range from 72.5 KN to 182 KN'),
  ActuatorModel(model: 'PLS-580', type: 'PLS', efficiency: 0.95, cylModel: 58, boreDia: 591.6, pistonArea: 274742.59, pRodDia: 42, pRodArea: 273357.85, remarks: 'PLS- 29 KN to 72.5 KN'),
  ActuatorModel(model: 'PLD-630', type: 'PLD', efficiency: 0.95, cylModel: 63, boreDia: 640.5, pistonArea: 322038.6, pRodDia: 50, pRodArea: 320076.1, remarks: 'Range from 85 KN to 212 KN'),
  ActuatorModel(model: 'PLS-630', type: 'PLS', efficiency: 0.95, cylModel: 63, boreDia: 640.5, pistonArea: 322038.6, pRodDia: 50, pRodArea: 320076.1, remarks: 'PLS- 34 KN to 85 KN'),
  ActuatorModel(model: 'PLD-680', type: 'PLD', efficiency: 0.95, cylModel: 68, boreDia: 689.6, pistonArea: 373305.31, pRodDia: 50, pRodArea: 371342.81, remarks: 'Range from 99 KN to 248 KN'),
  ActuatorModel(model: 'PLS-680', type: 'PLS', efficiency: 0.95, cylModel: 68, boreDia: 689.6, pistonArea: 373305.31, pRodDia: 50, pRodArea: 371342.81, remarks: 'PLS- 39.5 KN to 100 KN'),
  ActuatorModel(model: 'PLD-730', type: 'PLD', efficiency: 0.95, cylModel: 73, boreDia: 745, pistonArea: 435694.63, pRodDia: 60, pRodArea: 432868.63, remarks: 'Range from 115 KN to 289 KN'),
  ActuatorModel(model: 'PLS-730', type: 'PLS', efficiency: 0.95, cylModel: 73, boreDia: 745, pistonArea: 435694.63, pRodDia: 60, pRodArea: 432868.63, remarks: 'PLS- 46 KN to 115 KN'),
  ActuatorModel(model: 'PLD-780', type: 'PLD', efficiency: 0.95, cylModel: 78, boreDia: 790, pistonArea: 489918.5, pRodDia: 60, pRodArea: 487092.5, remarks: 'Range from 129.5 KN to 324 KN'),
  ActuatorModel(model: 'PLS-780', type: 'PLS', efficiency: 0.95, cylModel: 78, boreDia: 790, pistonArea: 489918.5, pRodDia: 60, pRodArea: 487092.5, remarks: 'PLS- 52 KN to 130 KN'),
  ActuatorModel(model: 'PLD-830', type: 'PLD', efficiency: 0.95, cylModel: 83, boreDia: 813, pistonArea: 518860.67, pRodDia: 60, pRodArea: 516034.67, remarks: 'Range from 137.5 KN to 345 KN'),
  ActuatorModel(model: 'PLS-830', type: 'PLS', efficiency: 0.95, cylModel: 83, boreDia: 813, pistonArea: 518860.67, pRodDia: 60, pRodArea: 516034.67, remarks: 'PLS- 55 KN to 138 KN'),
  ActuatorModel(model: 'PLD-880', type: 'PLD', efficiency: 0.95, cylModel: 88, boreDia: 880, pistonArea: 607904, pRodDia: 65, pRodArea: 604587.38, remarks: 'Range from 161 KN to 402 KN'),
  ActuatorModel(model: 'PLS-880', type: 'PLS', efficiency: 0.95, cylModel: 88, boreDia: 880, pistonArea: 607904, pRodDia: 65, pRodArea: 604587.38, remarks: 'PLS- 64 KN to 161 KN'),
  ActuatorModel(model: 'PLD-930', type: 'PLD', efficiency: 0.95, cylModel: 93, boreDia: 930, pistonArea: 678946.5, pRodDia: 65, pRodArea: 675629.88, remarks: 'Range from 179.5 KN to 450 KN'),
  ActuatorModel(model: 'PLS-930', type: 'PLS', efficiency: 0.95, cylModel: 93, boreDia: 930, pistonArea: 678946.5, pRodDia: 65, pRodArea: 675629.88, remarks: 'PLS- 72 KN to 180 KN'),
  ActuatorModel(model: 'PLD-980', type: 'PLD', efficiency: 0.95, cylModel: 98, boreDia: 975, pistonArea: 746240.63, pRodDia: 65, pRodArea: 742924, remarks: 'Range from 197.5 KN to 500 KN'),
  ActuatorModel(model: 'PLS-980', type: 'PLS', efficiency: 0.95, cylModel: 98, boreDia: 975, pistonArea: 746240.63, pRodDia: 65, pRodArea: 742924, remarks: 'PLS- 79 KN to 200 KN'),
];

List<int> get modelSizes {
  final sizes = actuatorModels.map((e) => int.parse(e.model.split('-')[1])).toList();
  return sizes.toSet().toList();
}

Map<String, ActuatorModel?> getModelPair(int size) {
  ActuatorModel? pld;
  ActuatorModel? pls;
  for (var m in actuatorModels) {
    if (m.model == 'PLD-$size') pld = m;
    if (m.model == 'PLS-$size') pls = m;
  }
  return {'pld': pld, 'pls': pls};
}
