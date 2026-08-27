import 'package:flutter/material.dart';

class OrbitSkin {
  const OrbitSkin({
    required this.id,
    required this.name,
    required this.primary,
    required this.glow,
    required this.cost,
  });

  final int id;
  final String name;
  final Color primary;
  final Color glow;
  final int cost;
}

const orbitSkins = <OrbitSkin>[
  OrbitSkin(
    id: 0,
    name: 'ION',
    primary: Color(0xFF55F6FF),
    glow: Color(0xFF0BA7FF),
    cost: 0,
  ),
  OrbitSkin(
    id: 1,
    name: 'NOVA',
    primary: Color(0xFFFF63E6),
    glow: Color(0xFFA928FF),
    cost: 80,
  ),
  OrbitSkin(
    id: 2,
    name: 'SOLAR',
    primary: Color(0xFFFFD166),
    glow: Color(0xFFFF6B35),
    cost: 180,
  ),
];

const gameBackground = Color(0xFF050816);
const gamePanel = Color(0xE611172A);
const dangerColor = Color(0xFFFF4D6D);
const crystalColor = Color(0xFF7CFFB2);
