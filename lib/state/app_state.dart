//A class to store all configs loaded during login
class AppConfig {
  static AppConfig instance = AppConfig(); //the single instance

  int apiTimeoutLimit = 30;
}

//A class to store the app's current state
class AppState {
  static AppState instance = AppState(); //the single instance

  void resetState() {}
}
