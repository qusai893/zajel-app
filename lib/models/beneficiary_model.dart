class BeneficiaryModel {
  final String firstName;
  final String fatherName;
  final String lastName;
  final String phone;
  final String mobile;
  final int cityId;
  final String cityName;

  BeneficiaryModel({
    required this.firstName,
    required this.fatherName,
    required this.lastName,
    required this.phone,
    required this.mobile,
    required this.cityId,
    required this.cityName,
  });

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'fatherName': fatherName,
        'lastName': lastName,
        'phone': phone,
        'mobile': mobile,
        'cityId': cityId,
        'cityName': cityName,
      };

  factory BeneficiaryModel.fromJson(Map<String, dynamic> json) =>
      BeneficiaryModel(
        firstName: json['firstName'],
        fatherName: json['fatherName'],
        lastName: json['lastName'],
        phone: json['phone'],
        mobile: json['mobile'],
        cityId: json['cityId'],
        cityName: json['cityName'],
      );
}
