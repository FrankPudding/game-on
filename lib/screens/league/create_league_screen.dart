import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/leagues_provider.dart';
import '../../models/league.dart';
import '../../theme/app_theme.dart';

class CreateLeagueScreen extends ConsumerStatefulWidget {
  const CreateLeagueScreen({super.key});

  @override
  ConsumerState<CreateLeagueScreen> createState() => _CreateLeagueScreenState();
}

class _CreateLeagueScreenState extends ConsumerState<CreateLeagueScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  // Simple
  final _winPointsController = TextEditingController(text: '3');
  final _drawPointsController = TextEditingController(text: '1');
  final _lossPointsController = TextEditingController(text: '0');

  // FirstTo
  final _targetScoreController = TextEditingController(text: '11');
  final _winByMarginController = TextEditingController(text: '2');

  // Timed
  bool _lowerScoreWins = false;

  // Frames
  final _framesToWinController = TextEditingController(text: '3');
  final _frameTypeController = TextEditingController(text: 'points');
  final _frameTargetScoreController = TextEditingController(text: '100');

  // Tennis
  final _setsToWinController = TextEditingController(text: '2');
  final _gamesPerSetController = TextEditingController(text: '6');
  final _tiebreakAtController = TextEditingController(text: '6');

  ScoringSystem _selectedSystem = ScoringSystem.simple;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _winPointsController.dispose();
    _drawPointsController.dispose();
    _lossPointsController.dispose();
    _targetScoreController.dispose();
    _winByMarginController.dispose();
    _framesToWinController.dispose();
    _frameTypeController.dispose();
    _frameTargetScoreController.dispose();
    _setsToWinController.dispose();
    _gamesPerSetController.dispose();
    _tiebreakAtController.dispose();
    super.dispose();
  }

  Future<void> _createLeague() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(leaguesProvider.notifier);
      final name = _nameController.text.trim();

      switch (_selectedSystem) {
        case ScoringSystem.simple:
          await notifier.addSimpleLeague(
            name: name,
            pointsForWin: int.parse(_winPointsController.text),
            pointsForDraw: int.parse(_drawPointsController.text),
            pointsForLoss: int.parse(_lossPointsController.text),
          );
          break;
        case ScoringSystem.firstTo:
          await notifier.addFirstToLeague(
            name: name,
            targetScore: int.parse(_targetScoreController.text),
            winByMargin: int.parse(_winByMarginController.text),
            placementPoints: [3, 0], // Default
          );
          break;
        case ScoringSystem.timed:
          await notifier.addTimedLeague(
            name: name,
            lowerScoreWins: _lowerScoreWins,
            placementPoints: [3, 1, 0], // Default
          );
          break;
        case ScoringSystem.frames:
          await notifier.addFramesLeague(
            name: name,
            framesToWin: int.parse(_framesToWinController.text),
            frameType: _frameTypeController.text,
            frameTargetScore: int.tryParse(_frameTargetScoreController.text),
            placementPoints: [3, 0], // Default
          );
          break;
        case ScoringSystem.tennis:
          await notifier.addTennisLeague(
            name: name,
            setsToWin: int.parse(_setsToWinController.text),
            gamesPerSet: int.parse(_gamesPerSetController.text),
            tiebreakAt: int.parse(_tiebreakAtController.text),
            placementPoints: [3, 0], // Default
          );
          break;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('League created successfully!'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New League')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('League Details'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'League Name',
                  hintText: 'e.g. Office Pool League',
                  prefixIcon: Icon(Icons.emoji_events),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter a name'
                    : null,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Scoring System'),
              const SizedBox(height: 16),
              DropdownButtonFormField<ScoringSystem>(
                value: _selectedSystem,
                decoration: const InputDecoration(
                  labelText: 'Game Type',
                  prefixIcon: Icon(Icons.sports_score),
                ),
                items: ScoringSystem.values.map((system) {
                  final isEnabled = system == ScoringSystem.simple;
                  return DropdownMenuItem(
                    value: system,
                    enabled: isEnabled,
                    child: Text(
                      system.name[0].toUpperCase() +
                          system.name.substring(1) +
                          (!isEnabled ? ' (Coming Soon)' : ''),
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.white24,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSystem = val);
                },
              ),
              const SizedBox(height: 24),
              _buildConfigForm(),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createLeague,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: Colors.black),
                        )
                      : const Text('Create League'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.mikadoYellow,
          ),
    );
  }

  Widget _buildConfigForm() {
    switch (_selectedSystem) {
      case ScoringSystem.simple:
        return _buildSimpleConfig();
      case ScoringSystem.firstTo:
        return _buildFirstToConfig();
      case ScoringSystem.timed:
        return _buildTimedConfig();
      case ScoringSystem.frames:
        return _buildFramesConfig();
      case ScoringSystem.tennis:
        return _buildTennisConfig();
    }
  }

  Widget _buildSimpleConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Scoring Rules (Simple)'),
        const SizedBox(height: 8),
        const Text('Points awarded for each match outcome.'),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildNumberField(_winPointsController, 'Win')),
            const SizedBox(width: 16),
            Expanded(child: _buildNumberField(_drawPointsController, 'Draw')),
            const SizedBox(width: 16),
            Expanded(child: _buildNumberField(_lossPointsController, 'Loss')),
          ],
        ),
      ],
    );
  }

  Widget _buildFirstToConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('First To Config'),
        const SizedBox(height: 16),
        _buildNumberField(_targetScoreController, 'Target Score (e.g. 11, 21)'),
        const SizedBox(height: 16),
        _buildNumberField(_winByMarginController, 'Win By Margin (e.g. 2)'),
      ],
    );
  }

  Widget _buildTimedConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Timed Game Config'),
        const SizedBox(height: 8),
        SwitchListTile(
          title: const Text('Lower Score Wins'),
          subtitle: const Text('e.g. Golf, Cross Country'),
          value: _lowerScoreWins,
          onChanged: (val) => setState(() => _lowerScoreWins = val),
          activeColor: AppTheme.mikadoYellow,
        ),
      ],
    );
  }

  Widget _buildFramesConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Frame-based Config'),
        const SizedBox(height: 16),
        _buildNumberField(_framesToWinController, 'Frames to Win (Best of X)'),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _frameTypeController.text,
          decoration: const InputDecoration(labelText: 'Frame Type'),
          items: const [
            DropdownMenuItem(
                value: 'points', child: Text('Points (e.g. Snooker)')),
            DropdownMenuItem(
                value: 'first_to', child: Text('First To (e.g. Darts legs)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _frameTypeController.text = val);
          },
        ),
      ],
    );
  }

  Widget _buildTennisConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Tennis Config'),
        const SizedBox(height: 16),
        _buildNumberField(_setsToWinController, 'Sets to Win'),
        const SizedBox(height: 16),
        _buildNumberField(_gamesPerSetController, 'Games per Set'),
        const SizedBox(height: 16),
        _buildNumberField(_tiebreakAtController, 'Tiebreak at (Games)'),
      ],
    );
  }

  Widget _buildNumberField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      validator: (v) => int.tryParse(v ?? '') == null ? 'Invalid' : null,
    );
  }
}
