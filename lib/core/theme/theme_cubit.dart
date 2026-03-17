import 'package:flutter_bloc/flutter_bloc.dart';
import '../constants/app_colors.dart';

class ThemeState {
  final bool isDarkMode;
  const ThemeState({this.isDarkMode = true});
  
  ThemeState copyWith({bool? isDarkMode}) {
    return ThemeState(isDarkMode: isDarkMode ?? this.isDarkMode);
  }
}

class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit() : super(const ThemeState());

  void toggleTheme() {
    final newMode = !state.isDarkMode;
    AppColors.isDarkMode = newMode;
    emit(state.copyWith(isDarkMode: newMode));
  }

  void setDarkMode(bool value) {
    AppColors.isDarkMode = value;
    emit(state.copyWith(isDarkMode: value));
  }
}
