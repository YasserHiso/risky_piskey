enum TimeBand { day, night }

class Scenario {
  final String name;
  final String weather;
  final String roadSurface;
  final String light;
  final String timeOfDay;

  const Scenario({
    required this.name,
    required this.weather,
    required this.roadSurface,
    required this.light,
    required this.timeOfDay,
  });

  bool get isNight => light.startsWith('Dark');
  bool get isRain => weather == 'Rain';
  bool get isFog => weather == 'Fog';
  bool get isStorm => weather == 'Storm';
  bool get isWet => roadSurface != 'Dry';

  Map<String, dynamic> toApiFields({
    required double speedKmh,
    required bool seatbeltWorn,
  }) {
    return {
      'speed_kmh': speedKmh,
      'seatbelt_worn': seatbeltWorn ? 'Yes' : 'No',
      'weather_condition': weather,
      'road_surface': roadSurface,
      'light_condition': light,
      'time_of_day': timeOfDay,
    };
  }
}

const List<Scenario> kScenarios = [
  Scenario(
    name: 'Clear Day',
    weather: 'Clear',
    roadSurface: 'Dry',
    light: 'Daylight',
    timeOfDay: 'Afternoon',
  ),
  Scenario(
    name: 'Rainy Day',
    weather: 'Rain',
    roadSurface: 'Wet',
    light: 'Daylight',
    timeOfDay: 'Afternoon',
  ),
  Scenario(
    name: 'Foggy Night',
    weather: 'Fog',
    roadSurface: 'Wet',
    light: 'Dark_Lit',
    timeOfDay: 'Night',
  ),
  Scenario(
    name: 'Stormy Night',
    weather: 'Storm',
    roadSurface: 'Wet',
    light: 'Dark_Unlit',
    timeOfDay: 'Night',
  ),
  Scenario(
    name: 'Clear Night',
    weather: 'Clear',
    roadSurface: 'Dry',
    light: 'Dark_Lit',
    timeOfDay: 'Night',
  ),
];
