import 'dart:async';

import '../datasources/remote/xtream_api.dart';

class ContentSyncProgress {
  final String stepLabel;
  final int currentStep;
  final int totalSteps;

  const ContentSyncProgress({
    required this.stepLabel,
    required this.currentStep,
    required this.totalSteps,
  });

  double get value => totalSteps == 0 ? 0 : currentStep / totalSteps;
}

class ContentSyncService {
  final XtreamApi _xtreamApi;
  final StreamController<ContentSyncProgress> _progressController =
      StreamController<ContentSyncProgress>.broadcast();

  ContentSyncService({required XtreamApi xtreamApi}) : _xtreamApi = xtreamApi;

  Stream<ContentSyncProgress> get progressStream => _progressController.stream;

  Future<void> syncInitialContent() => _sync(forceRefresh: false);

  Future<void> syncRefreshContent() => _sync(forceRefresh: true);

  Future<void> _sync({required bool forceRefresh}) async {
    if (forceRefresh) {
      XtreamApi.clearAllInMemoryCaches();
    }

    const totalSteps = 7;
    var currentStep = 0;

    Future<void> runStep(String label, Future<void> Function() action) async {
      currentStep += 1;
      _progressController.add(
        ContentSyncProgress(
          stepLabel: label,
          currentStep: currentStep,
          totalSteps: totalSteps,
        ),
      );
      await action();
    }

    await runStep('Loading account info', () async {
      await _xtreamApi.getAccountInfo();
    });
    await runStep('Loading live TV categories', () async {
      await _xtreamApi.getLiveCategories();
    });
    await runStep('Loading live TV streams', () async {
      await _xtreamApi.getLiveStreams();
    });
    await runStep('Loading movie categories', () async {
      await _xtreamApi.getVodCategories();
    });
    await runStep('Loading movies', () async {
      await _xtreamApi.getVodStreamsStrict();
    });
    await runStep('Loading series categories', () async {
      await _xtreamApi.getSeriesCategories();
    });
    await runStep('Loading series', () async {
      await _xtreamApi.getSeries();
    });
  }

  void dispose() {
    _progressController.close();
  }
}
