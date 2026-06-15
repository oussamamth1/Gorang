class Routes {
  Routes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String kyc = '/kyc';
  static const String addVehicle = '/add-vehicle';
  static const String editVehicle = '/edit-vehicle';
  static const String vehicleDetail = '/vehicle/:id';
  static const String bookingDetail = '/booking/:id';
  static const String rentalContract = '/booking/:id/contract';
  static const String favorites = '/favorites';
  static const String notifications = '/notifications';
  static const String editProfile = '/edit-profile';

  static String vehicleDetailPath(String id) => '/vehicle/$id';
  static String bookingDetailPath(String id) => '/booking/$id';
  static String rentalContractPath(String id) => '/booking/$id/contract';
}
