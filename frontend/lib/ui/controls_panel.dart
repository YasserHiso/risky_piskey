import 'package:flutter/material.dart';

class ControlsPanel extends StatelessWidget {
  final double speedKmh;
  final bool seatbeltWorn;
  final ValueChanged<double> onSpeedChanged;
  final ValueChanged<bool> onSeatbeltChanged;

  static const double minSpeed = 0;
  static const double maxSpeed = 200;

  const ControlsPanel({
    super.key,
    required this.speedKmh,
    required this.seatbeltWorn,
    required this.onSpeedChanged,
    required this.onSeatbeltChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF18212F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: .09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Speed', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12.5)),
              Text(
                '${speedKmh.round()} km/h',
                style: const TextStyle(
                  color: Color(0xFFE9EEF6),
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbColor: Colors.white,
              activeTrackColor: const Color(0xFF31D08C),
              inactiveTrackColor: Colors.white.withValues(alpha: .11),
              overlayShape: SliderComponentShape.noOverlay,
            ),
            child: Slider(
              value: speedKmh,
              min: minSpeed,
              max: maxSpeed,
              onChanged: onSpeedChanged,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Color(0xFF63708A))),
                Text('200 km/h', style: TextStyle(fontFamily: 'monospace', fontSize: 9.5, color: Color(0xFF63708A))),
              ],
            ),
          ),
          Container(margin: const EdgeInsets.symmetric(vertical: 13), height: 1, color: Colors.white.withValues(alpha: .09)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Seatbelt', style: TextStyle(color: Color(0xFF8B98AD), fontSize: 12.5)),
              Row(
                children: [
                  Text(
                    seatbeltWorn ? 'ON' : 'OFF',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: .8,
                      color: seatbeltWorn ? const Color(0xFF31D08C) : const Color(0xFFFF4B5C),
                    ),
                  ),
                  const SizedBox(width: 9),
                  GestureDetector(
                    onTap: () => onSeatbeltChanged(!seatbeltWorn),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      height: 28,
                      padding: const EdgeInsets.all(3),
                      alignment: seatbeltWorn ? Alignment.centerRight : Alignment.centerLeft,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: seatbeltWorn ? const Color(0xFF31D08C).withValues(alpha: .28) : Colors.white.withValues(alpha: .13),
                        border: Border.all(
                          color: seatbeltWorn ? const Color(0xFF31D08C).withValues(alpha: .6) : Colors.white.withValues(alpha: .09),
                        ),
                      ),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: seatbeltWorn ? const Color(0xFF31D08C) : const Color(0xFF9AA6B8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
