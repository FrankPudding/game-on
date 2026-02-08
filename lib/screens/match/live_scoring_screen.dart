import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/league.dart';
import '../../scoring/scoring_handler.dart';
import '../../scoring/simple/simple_handler.dart';
import '../../scoring/first_to/first_to_handler.dart';
import '../../scoring/timed/timed_handler.dart';
import '../../scoring/frames/frames_handler.dart';
import '../../scoring/tennis/tennis_handler.dart';

class LiveScoringScreen extends ConsumerStatefulWidget {
  final String leagueId;
  final ScoringSystem scoringSystem;

  const LiveScoringScreen({
    super.key,
    required this.leagueId,
    required this.scoringSystem,
  });

  @override
  ConsumerState<LiveScoringScreen> createState() => _LiveScoringScreenState();
}

class _LiveScoringScreenState extends ConsumerState<LiveScoringScreen> {
  late ScoringHandler _handler;
  dynamic _currentMatch; // This will hold the match model being built

  @override
  void initState() {
    super.initState();
    _initHandler();
  }

  void _initHandler() {
    switch (widget.scoringSystem) {
      case ScoringSystem.simple:
        _handler = SimpleHandler();
        break;
      case ScoringSystem.firstTo:
        _handler = FirstToHandler();
        break;
      case ScoringSystem.timed:
        _handler = TimedHandler();
        break;
      case ScoringSystem.frames:
        _handler = FramesHandler();
        break;
      case ScoringSystem.tennis:
        _handler = TennisHandler();
        break;
    }
    // Initialize current match with empty teams for now
    _currentMatch = _handler.createMatch(widget.leagueId, []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.scoringSystem.name.toUpperCase()} Match'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _handler.buildScoreDisplay(_currentMatch),
            const SizedBox(height: 32),
            _handler.buildScoreTracker(_currentMatch, () {
              setState(() {}); // Refresh UI on score updates
            }),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                // Submit match logic here
                Navigator.pop(context);
              },
              child: const Text('Finish Match'),
            ),
          ],
        ),
      ),
    );
  }
}
