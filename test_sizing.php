<?php

$actuatorModels = [
  ['model' => 'PLD-100', 'type' => 'PLD', 'efficiency' => 0.95, 'boreDia' => 100, 'pistonArea' => 7850, 'pRodDia' => 25, 'pRodArea' => 7359.38],
  ['model' => 'PLS-100', 'type' => 'PLS', 'efficiency' => 0.95, 'boreDia' => 100, 'pistonArea' => 7850, 'pRodDia' => 25, 'pRodArea' => 7359.38],
  ['model' => 'PLD-125', 'type' => 'PLD', 'efficiency' => 0.95, 'boreDia' => 127, 'pistonArea' => 12661.27, 'pRodDia' => 25, 'pRodArea' => 12170.64],
  ['model' => 'PLS-125', 'type' => 'PLS', 'efficiency' => 0.95, 'boreDia' => 127, 'pistonArea' => 12661.27, 'pRodDia' => 25, 'pRodArea' => 12170.64],
  ['model' => 'PLD-160', 'type' => 'PLD', 'efficiency' => 0.95, 'boreDia' => 160, 'pistonArea' => 20096, 'pRodDia' => 25, 'pRodArea' => 19605.38],
  ['model' => 'PLS-160', 'type' => 'PLS', 'efficiency' => 0.95, 'boreDia' => 160, 'pistonArea' => 20096, 'pRodDia' => 25, 'pRodArea' => 19605.38]
];

function testRecalculate($type, $valveThrust, $pressure, $failAction) {
  global $actuatorModels;
  $modelSizes = [100, 125, 160];
  
  $bestSize = null;
  $bestSf = 9999;
  $targetSf = $type === 'PLD' ? 1.3 : 1.5;

  foreach ($modelSizes as $size) {
    // Find pair
    $pld = null;
    $pls = null;
    foreach ($actuatorModels as $m) {
      if ($m['model'] === "PLD-$size") $pld = $m;
      if ($m['model'] === "PLS-$size") $pls = $m;
    }
    if (!$pld || !$pls) continue;

    $sf = 0.0;
    if ($type === 'PLD') {
      $pldCloseN = ($pressure / 10) * $pld['pistonArea'] * $pld['efficiency'];
      $pldOpenN = ($pressure / 10) * $pld['pRodArea'] * $pld['efficiency'];
      $activeForceN = $failAction === 'FC' ? $pldCloseN : $pldOpenN;
      $sf = $activeForceN / $valveThrust;
    } else {
      $cylinderForceN = ($pressure / 10) * $pls['pistonArea'] * $pls['efficiency'];
      $springStartN = $cylinderForceN * 0.35;
      $springEndN = $cylinderForceN * 0.70;

      if ($failAction === 'FC') {
        $plsSpringCloseN = $springStartN;
        $plsAirOpenEndN = $cylinderForceN - $springEndN;
        $sf = min($plsSpringCloseN / $valveThrust, $plsAirOpenEndN / $valveThrust);
      } else {
        $plsSpringOpenN = $springStartN;
        $plsAirCloseEndN = $cylinderForceN - $springEndN;
        $sf = min($plsSpringOpenN / $valveThrust, $plsAirCloseEndN / $valveThrust);
      }
    }

    echo "Size $size: SF = " . round($sf, 3) . "\n";

    if ($sf >= $targetSf && $sf < $bestSf) {
      $bestSf = $sf;
      $bestSize = $size;
    }
  }

  echo "==> Best Size selected: " . ($bestSize ?? "None") . " with SF = " . round($bestSf, 3) . "\n\n";
}

echo "Testing PLD at 1000 N, 4.2 bar:\n";
testRecalculate('PLD', 1000, 4.2, 'FC');

echo "Testing PLS at 1000 N, 4.2 bar:\n";
testRecalculate('PLS', 1000, 4.2, 'FC');

echo "Testing PLS at 2000 N, 4.2 bar:\n";
testRecalculate('PLS', 2000, 4.2, 'FC');

?>
