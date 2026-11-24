/// Modelo de un usuario tal como lo devuelve la API.
class UserModel {
  final int id;
  final String nombre;
  final String correo;
  final String? direccion;
  // 1 = Administrador, 2 = Usuario general.
  final int tipoUsuario;

  UserModel({
    required this.id,
    required this.nombre,
    required this.correo,
    this.direccion,
    this.tipoUsuario = 1,
  });

  /// Convierte el JSON de la API en un UserModel.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id_usr'] as int,
      nombre: json['nom_usr'] as String,
      correo: json['mail'] as String,
      direccion: json['dir_usr'] as String?,
      tipoUsuario: json['tip_usu'] as int? ?? 1,
    );
  }
}
