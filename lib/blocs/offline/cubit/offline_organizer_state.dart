import 'package:Orvia/core/models/offline_organizer_models.dart';
import 'package:equatable/equatable.dart';

abstract class OfflineOrganizerState extends Equatable {
  const OfflineOrganizerState();

  @override
  List<Object?> get props => [];
}

class OfflineOrganizerInitial extends OfflineOrganizerState {}

class OfflineOrganizerLoading extends OfflineOrganizerState {}

class OfflineOrganizerLoaded extends OfflineOrganizerState {
  final List<OfflineFolder> folders;
  final List<OfflineCollection> collections;

  const OfflineOrganizerLoaded({
    required this.folders,
    required this.collections,
  });

  OfflineOrganizerLoaded copyWith({
    List<OfflineFolder>? folders,
    List<OfflineCollection>? collections,
  }) {
    return OfflineOrganizerLoaded(
      folders: folders ?? this.folders,
      collections: collections ?? this.collections,
    );
  }

  @override
  List<Object?> get props => [folders, collections];
}

