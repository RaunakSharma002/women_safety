import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import 'package:http/http.dart' as http;
import 'package:women_safety/Assistants/request_assistant.dart';

import '../global/map_key.dart';
import '../infoHandler/app_info.dart';
import '../models/direction_details_info.dart';
import '../models/directions.dart';


class AssistantMethods {

    static Future<String> searchAddressForGeographicCoOrdinates(Position position, context) async{
      String apiUrl = "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey";
      String humanReadableAddress = "";

      var requestResponse = await RequestAssistant.recieveRequest(apiUrl);
      if(requestResponse != "failedResponse"){
        humanReadableAddress =  requestResponse["results"][0]["formatted_address"];//fromatted_addresss

        Directions userPickupAddress = Directions();
        userPickupAddress.locationLatitude = position.latitude;
        userPickupAddress.locationLongitude = position.longitude;
        userPickupAddress.locationName = humanReadableAddress;

        Provider.of<AppInfo>(context, listen: false).updatePickUpLocationAddress(userPickupAddress);
      }
      return humanReadableAddress;
    }

    static Future<DirectionDetailsInfo> obtainedOriginToDestinationDirectionDetails(LatLng originPosition, LatLng destinationPosition) async{
      String urlOriginToDestinationDirectionDetails = "https://maps.googleapis.com/maps/api/directions/json?origin=${originPosition.latitude},${originPosition.longitude}&destination=${destinationPosition.latitude},${destinationPosition.longitude}&key=$mapKey";
      var responseDirectionApi = await RequestAssistant.recieveRequest(urlOriginToDestinationDirectionDetails);

      // if(responseDirectionApi == "failedResponse"){
      //   return null;
      // }

      print("multiple routes ${responseDirectionApi}");
      DirectionDetailsInfo directionDetailsInfo = DirectionDetailsInfo();
      directionDetailsInfo.e_points = responseDirectionApi["routes"][0]["overview_polyline"]["points"];

      directionDetailsInfo.distance_text = responseDirectionApi["routes"][0]["legs"][0]["distance"]["text"];
      directionDetailsInfo.distance_value = responseDirectionApi["routes"][0]["legs"][0]["distance"]["value"];

      directionDetailsInfo.duration_text = responseDirectionApi["routes"][0]["legs"][0]["duration"]["text"];
      directionDetailsInfo.duration_value = responseDirectionApi["routes"][0]["legs"][0]["duration"]["value"];
      return directionDetailsInfo;
    }









}