import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() => runApp(const WeatherlyApp());

class WeatherlyApp extends StatelessWidget {
  const WeatherlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weatherly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const WeatherHomePage(),
    );
  }
}

/// --------------------
/// Models
/// --------------------

class GeoResult {
  final String name;
  final String country;
  final double lat;
  final double lon;
  final String timezone;

  GeoResult({
    required this.name,
    required this.country,
    required this.lat,
    required this.lon,
    required this.timezone,
  });

  factory GeoResult.fromJson(Map<String, dynamic> j) {
    return GeoResult(
      name: (j['name'] ?? '').toString(),
      country: (j['country'] ?? '').toString(),
      lat: (j['latitude'] as num).toDouble(),
      lon: (j['longitude'] as num).toDouble(),
      timezone: (j['timezone'] ?? 'UTC').toString(),
    );
  }
}

class WeatherData {
  final String timezone;
  final CurrentWeather current;
  final List<HourlyPoint> hourly;
  final List<DailyPoint> daily;

  WeatherData({
    required this.timezone,
    required this.current,
    required this.hourly,
    required this.daily,
  });
}

class CurrentWeather {
  final DateTime time;
  final double tempC;
  final double windKph;
  final int weatherCode;
  final double feelsLikeC;
  final int humidity;

  CurrentWeather({
    required this.time,
    required this.tempC,
    required this.windKph,
    required this.weatherCode,
    required this.feelsLikeC,
    required this.humidity,
  });
}

class HourlyPoint {
  final DateTime time;
  final double tempC;
  final int weatherCode;
  final int precipitationProb;

  HourlyPoint({
    required this.time,
    required this.tempC,
    required this.weatherCode,
    required this.precipitationProb,
  });
}

class DailyPoint {
  final DateTime date;
  final double maxC;
  final double minC;
  final int weatherCode;
  final int precipitationProbMax;

  DailyPoint({
    required this.date,
    required this.maxC,
    required this.minC,
    required this.weatherCode,
    required this.precipitationProbMax,
  });
}

/// --------------------
/// Repository (Open-Meteo)
/// --------------------

class WeatherRepository {
  static const _geoBase = 'https://geocoding-api.open-meteo.com/v1/search';
  static const _forecastBase = 'https://api.open-meteo.com/v1/forecast';

  Future<GeoResult> geocodeCity(String city) async {
    final uri = Uri.parse(_geoBase).replace(queryParameters: {
      'name': city,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Geocoding failed (${res.statusCode})');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? [];
    if (results.isEmpty) {
      throw Exception('No results for "$city"');
    }

    return GeoResult.fromJson(results.first as Map<String, dynamic>);
  }

  Future<WeatherData> fetchWeather({
    required double lat,
    required double lon,
    required String timezone,
  }) async {
    final uri = Uri.parse(_forecastBase).replace(queryParameters: {
      'latitude': '$lat',
      'longitude': '$lon',
      'timezone': timezone,
      'current': 'temperature_2m,weather_code,relative_humidity_2m,apparent_temperature,wind_speed_10m',
      'hourly': 'temperature_2m,weather_code,precipitation_probability',
      'daily': 'temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max',
      'forecast_days': '7',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Forecast failed (${res.statusCode})');
    }

    final j = jsonDecode(res.body) as Map<String, dynamic>;

    final tz = (j['timezone'] ?? timezone).toString();

    // Current
    final currentJson = (j['current'] as Map<String, dynamic>);
    final current = CurrentWeather(
      time: DateTime.parse(currentJson['time'] as String),
      tempC: (currentJson['temperature_2m'] as num).toDouble(),
      weatherCode: (currentJson['weather_code'] as num).toInt(),
      humidity: (currentJson['relative_humidity_2m'] as num).toInt(),
      feelsLikeC: (currentJson['apparent_temperature'] as num).toDouble(),
      windKph: ((currentJson['wind_speed_10m'] as num).toDouble()) * 3.6, // m/s -> kph
    );

    // Hourly
    final hourlyJson = (j['hourly'] as Map<String, dynamic>);
    final hourlyTimes = (hourlyJson['time'] as List).cast<String>();
    final hourlyTemps = (hourlyJson['temperature_2m'] as List).cast<num>();
    final hourlyCodes = (hourlyJson['weather_code'] as List).cast<num>();
    final hourlyPop = (hourlyJson['precipitation_probability'] as List).cast<num>();

    final now = DateTime.now();
    final hourly = <HourlyPoint>[];
    for (int i = 0; i < hourlyTimes.length; i++) {
      final t = DateTime.parse(hourlyTimes[i]);
      if (t.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      hourly.add(HourlyPoint(
        time: t,
        tempC: hourlyTemps[i].toDouble(),
        weatherCode: hourlyCodes[i].toInt(),
        precipitationProb: hourlyPop[i].toInt(),
      ));
      if (hourly.length >= 24) break; // next 24h
    }

    // Daily
    final dailyJson = (j['daily'] as Map<String, dynamic>);
    final dailyTimes = (dailyJson['time'] as List).cast<String>();
    final dailyMax = (dailyJson['temperature_2m_max'] as List).cast<num>();
    final dailyMin = (dailyJson['temperature_2m_min'] as List).cast<num>();
    final dailyCodes = (dailyJson['weather_code'] as List).cast<num>();
    final dailyPopMax = (dailyJson['precipitation_probability_max'] as List).cast<num>();

    final daily = <DailyPoint>[];
    for (int i = 0; i < dailyTimes.length; i++) {
      daily.add(DailyPoint(
        date: DateTime.parse(dailyTimes[i]),
        maxC: dailyMax[i].toDouble(),
        minC: dailyMin[i].toDouble(),
        weatherCode: dailyCodes[i].toInt(),
        precipitationProbMax: dailyPopMax[i].toInt(),
      ));
    }

    return WeatherData(timezone: tz, current: current, hourly: hourly, daily: daily);
  }
}

/// --------------------
/// UI
/// --------------------

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  State<WeatherHomePage> createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> {
  final _repo = WeatherRepository();
  final _controller = TextEditingController(text: 'London');

  bool _loading = false;
  String? _error;
  GeoResult? _place;
  WeatherData? _data;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final city = _controller.text.trim();
    if (city.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final geo = await _repo.geocodeCity(city);
      final weather = await _repo.fetchWeather(lat: geo.lat, lon: geo.lon, timezone: geo.timezone);

      setState(() {
        _place = geo;
        _data = weather;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final data = _data;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Weatherly'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SearchBar(
                controller: _controller,
                onSearch: _search,
                loading: _loading,
              ),
              const SizedBox(height: 12),
              if (_error != null) _ErrorCard(message: _error!),
              if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
              if (!_loading && _error == null && place != null && data != null)
                Expanded(
                  child: ListView(
                    children: [
                      _HeroCard(place: place, data: data),
                      const SizedBox(height: 12),
                      _HourlyStrip(hourly: data.hourly),
                      const SizedBox(height: 12),
                      _DailyForecast(daily: data.daily),
                      const SizedBox(height: 12),
                      _DetailsGrid(current: data.current),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSearch;
  final bool loading;

  const _SearchBar({
    required this.controller,
    required this.onSearch,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Search city (e.g., London, Tokyo)',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: loading ? null : onSearch,
          child: const Text('Go'),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final GeoResult place;
  final WeatherData data;

  const _HeroCard({required this.place, required this.data});

  @override
  Widget build(BuildContext context) {
    final c = data.current;
    final timeStr = DateFormat('EEE, MMM d • HH:mm').format(c.time);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${place.name}, ${place.country}', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(timeStr, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${c.tempC.round()}°',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _codeToSummary(c.weatherCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Spacer(),
                Icon(_codeToIcon(c.weatherCode), size: 44),
              ],
            ),
            const SizedBox(height: 10),
            Text('Feels like ${c.feelsLikeC.round()}° • Humidity ${c.humidity}% • Wind ${c.windKph.round()} km/h'),
          ],
        ),
      ),
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  final List<HourlyPoint> hourly;
  const _HourlyStrip({required this.hourly});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next 24 hours', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: hourly.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final h = hourly[i];
                  return Container(
                    width: 80,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('HH:mm').format(h.time)),
                        const SizedBox(height: 6),
                        Icon(_codeToIcon(h.weatherCode)),
                        const SizedBox(height: 6),
                        Text('${h.tempC.round()}°', style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('${h.precipitationProb}%', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _DailyForecast extends StatelessWidget {
  final List<DailyPoint> daily;
  const _DailyForecast({required this.daily});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('7-day forecast', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...daily.map((d) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(width: 70, child: Text(DateFormat('EEE').format(d.date))),
                    Icon(_codeToIcon(d.weatherCode)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_codeToSummary(d.weatherCode))),
                    Text('${d.minC.round()}° / ${d.maxC.round()}°'),
                    const SizedBox(width: 10),
                    SizedBox(width: 45, child: Text('${d.precipitationProbMax}%')),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DetailsGrid extends StatelessWidget {
  final CurrentWeather current;
  const _DetailsGrid({required this.current});

  @override
  Widget build(BuildContext context) {
    final items = <_DetailItem>[
      _DetailItem(icon: Icons.thermostat, label: 'Feels like', value: '${current.feelsLikeC.round()}°C'),
      _DetailItem(icon: Icons.water_drop, label: 'Humidity', value: '${current.humidity}%'),
      _DetailItem(icon: Icons.air, label: 'Wind', value: '${current.windKph.round()} km/h'),
      _DetailItem(icon: Icons.cloud, label: 'Code', value: '${current.weatherCode}'),
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => items[i],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// --------------------
/// Weather code helpers (Open-Meteo WMO codes)
/// --------------------

String _codeToSummary(int code) {
  // This is intentionally simple; you can expand it.
  if (code == 0) return 'Clear';
  if (code == 1 || code == 2) return 'Mostly clear';
  if (code == 3) return 'Overcast';
  if (code == 45 || code == 48) return 'Fog';
  if (code >= 51 && code <= 57) return 'Drizzle';
  if (code >= 61 && code <= 67) return 'Rain';
  if (code >= 71 && code <= 77) return 'Snow';
  if (code >= 80 && code <= 82) return 'Showers';
  if (code >= 95) return 'Thunderstorm';
  return 'Unknown';
}

IconData _codeToIcon(int code) {
  if (code == 0) return Icons.wb_sunny_outlined;
  if (code == 1 || code == 2) return Icons.wb_cloudy_outlined;
  if (code == 3) return Icons.cloud_outlined;
  if (code == 45 || code == 48) return Icons.foggy;
  if (code >= 51 && code <= 57) return Icons.grain;
  if (code >= 61 && code <= 67) return Icons.umbrella_outlined;
  if (code >= 71 && code <= 77) return Icons.ac_unit;
  if (code >= 80 && code <= 82) return Icons.beach_access_outlined;
  if (code >= 95) return Icons.thunderstorm_outlined;
  return Icons.help_outline;
}
