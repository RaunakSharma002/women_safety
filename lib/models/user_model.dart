
//Creating to fetch data from Firebase and stored locally
import 'package:firebase_database/firebase_database.dart';

class UserModel{
  String? phone;
  String? name;
  String? id;
  String? email;
  String? address;

  UserModel({this.phone, this.name, this.id, this.email, this.address});

  UserModel.fromSnapshot(DataSnapshot snap){
    phone = (snap.value as dynamic)["phone"];
    name = (snap.value as dynamic)["name"];
    id = snap.key;
    email = (snap.value as dynamic)["email"];
    address = (snap.value as dynamic)["address"];
  }
}