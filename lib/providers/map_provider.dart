import 'dart:async';
import 'package:flutter/material.dart';
import '../models/waste_report_model.dart';
import '../services/firestore_service.dart';

class MapProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  List<WasteReportModel> _reports = [];
  StreamSubscription<List<WasteReportModel>>? _reportsSub;
  WasteReportModel? _selectedReport;
  String _currentFilter = 'all'; // 'all' | 'pending' | 'resolved'
  bool _isLoading = false;
  String? _errorMessage;

  MapProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService() {
    _initReportsStream();
  }

  List<WasteReportModel> get allReports =>
      _reports.where((r) => !r.isExpired).toList();
  WasteReportModel? get selectedReport => _selectedReport;
  String get currentFilter => _currentFilter;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<WasteReportModel> get filteredReports {
    final active = allReports;
    if (_currentFilter == 'pending') {
      return active.where((r) => r.status == 'pending').toList();
    } else if (_currentFilter == 'resolved') {
      return active.where((r) => r.status == 'resolved').toList();
    }
    return active;
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void selectReport(WasteReportModel? report) {
    _selectedReport = report;
    notifyListeners();
  }

  void _initReportsStream() {
    _isLoading = true;
    notifyListeners();

    try {
      _reportsSub = _firestoreService.getWasteReportsStream().listen(
        (data) {
          if (data.isEmpty) {
            _reports = _getSampleReports();
          } else {
            _reports = data;
          }
          _isLoading = false;
          notifyListeners();
        },
        onError: (e) {
          debugPrint('[MapProvider] Harita akış hatası: $e');
          _reports = _getSampleReports();
          _isLoading = false;
          notifyListeners();
        },
      );
    } catch (e) {
      debugPrint('[MapProvider] Servis başlatılamadı, fallback verileri yükleniyor: $e');
      _reports = _getSampleReports();
      _isLoading = false;
      notifyListeners();
    }
  }

  List<WasteReportModel> _getSampleReports() =>
      FirestoreService.createDefaultSampleReports();

  Future<bool> createReport(WasteReportModel report) async {
    try {
      await _firestoreService.createReport(report);
      if (!_reports.any((r) => r.id == report.id)) {
        _reports.insert(0, report);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'İhbar kaydedilemedi: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> markReportResolved(String reportId, String solverUid) async {
    try {
      await _firestoreService.markReportResolved(reportId, solverUid);

      // Yerel listeyi güncelle
      final index = _reports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        _reports[index] = _reports[index].copyWith(
          status: 'resolved',
          resolvedBy: solverUid,
          resolvedAt: DateTime.now(),
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = 'İhbar güncellenemedi: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteReport(String reportId, {String? userId}) async {
    try {
      await _firestoreService.deleteReport(reportId, userId: userId);
      _reports.removeWhere((r) => r.id == reportId);
      if (_selectedReport?.id == reportId) {
        _selectedReport = null;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'İhbar silinemedi: $e';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _reportsSub?.cancel();
    super.dispose();
  }
}

