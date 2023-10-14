import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:location/location.dart' as loc;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:women_safety/screens/search_places_screen.dart';

import '../Assistants/assistant_methods.dart';
import '../Assistants/geofire_assistant.dart';
import '../global/global.dart';
import '../infoHandler/app_info.dart';
import '../models/active_nearby_available_drivers.dart';
import '../models/directions.dart';
import '../widgets/progress_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  LatLng? pickLocation;
  loc.Location location = loc.Location();
  String? _address;
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

  double searchLocationContainerHeight = 220;
  double waitingResponsefromDriverContainerHeight = 0;
  double assignedDriverInfoContainerHeight = 0;
  double suggestedRidesContainerHeight = 0;
  double searchingForDriverContainerHeight = 0;

  Position? userCurrentPosition;
  var geoLocation = Geolocator();

  LocationPermission? _locationPermission;
  double bottomPaddingOfMap = 0;

  List<LatLng> pLineCoOrdinatesList = [];
  Set<Polyline> polylineSet = {};
  Set<Marker> markerSet = {};
  Set<Circle> circleSet = {};

  String userName = "";
  String userEmail = "";

  bool openNavigationDrawer = true;

  bool activeNearbyDriverKeysLoaded = false;
  BitmapDescriptor? activeNearByIcon; //use in show Driver (displayActiveDriversOnUserMap())

  DatabaseReference? referenceRideRequest;//save ride Request info(saveRideRequestInformation())
  String selectedVehicleType = ""; //use in show Fare

  String driverRideStatus  = "Driver is coming";
  StreamSubscription<DatabaseEvent>? tripRideRequestInfoStreamSubscription;
  String userRideRequestStatus = "";

  List<ActiveNearByAvailableDrivers> onlineNearByAvailableDriversList = [];

  bool requestPositionInfo = true;

  locateUserPosition() async {
    Position cPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    CameraPosition cameraPosition = CameraPosition(target: latLngPosition, zoom: 15);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
    
    String humanReadableAddress = await AssistantMethods.searchAddressForGeographicCoOrdinates(userCurrentPosition!, context);

    userName = userModelCurrentInfo!.name!;
    userEmail = userModelCurrentInfo!.email!;


  }

  Future<void> drawPolyLineFromOriginToDestination(bool darkTheme) async{
    var originPosition = Provider.of<AppInfo>(context, listen: false).userPickUpLocation;
    var destinationPosition = Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

    var originLatLng = LatLng(originPosition!.locationLatitude!, originPosition.locationLongitude!);
    var destinationLatLng = LatLng(destinationPosition!.locationLatitude!, destinationPosition.locationLongitude!);


    showDialog(
        context: context,
        builder: (BuildContext context) => ProgressDialog(message: "Please wait...",),
    );

    var directionDetailsInfo = await AssistantMethods.obtainedOriginToDestinationDirectionDetails(originLatLng, destinationLatLng);
    setState(() {
      tripDirectionDetailsInfo = directionDetailsInfo;
    });


    Navigator.pop(context);

    PolylinePoints pPoints = PolylinePoints();
    List<PointLatLng> decodePolyLinePointsResultList = pPoints.decodePolyline(directionDetailsInfo.e_points!);

    pLineCoOrdinatesList.clear();
    if(decodePolyLinePointsResultList.isNotEmpty){
      decodePolyLinePointsResultList.forEach((PointLatLng pointLatLng) {
        pLineCoOrdinatesList.add(LatLng(pointLatLng.latitude, pointLatLng.longitude));
      });
    }

    polylineSet.clear();
    setState(() {
      Polyline polyline = Polyline(
        color: darkTheme ? Colors.amberAccent : Colors.blue,
        polylineId: PolylineId("PolylineID"),
        jointType: JointType.round,
        points: pLineCoOrdinatesList,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        width: 5,
      );
      polylineSet.add(polyline);
    });

    LatLngBounds boundsLatLng;
    if(originLatLng.latitude > destinationLatLng.latitude && originLatLng.longitude > destinationLatLng.longitude){
      boundsLatLng = LatLngBounds(southwest: destinationLatLng, northeast: originLatLng);
    }
    else if(originLatLng.longitude > destinationLatLng.longitude){
      boundsLatLng = LatLngBounds(
          southwest: LatLng(originLatLng.latitude, destinationLatLng.longitude),
          northeast: LatLng(destinationLatLng.latitude, originLatLng.longitude)
      );
    }
    else if(originLatLng.latitude > destinationLatLng.latitude){
      boundsLatLng = LatLngBounds(
          southwest: LatLng(destinationLatLng.latitude, originLatLng.longitude),
          northeast: LatLng(originLatLng.latitude, destinationLatLng.longitude)
      );
    }
    else{
      boundsLatLng = LatLngBounds(southwest: originLatLng, northeast: destinationLatLng);
    }

    newGoogleMapController!.animateCamera(CameraUpdate.newLatLngBounds(boundsLatLng, 65));

    Marker originMarker = Marker(
      markerId: MarkerId("originID"),
      infoWindow: InfoWindow(title: originPosition.locationName, snippet: "Origin"),
      position:  originLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    Marker destinationMarker = Marker(
      markerId: MarkerId("destinationID"),
      infoWindow: InfoWindow(title: destinationPosition.locationName, snippet: "Destination"),
      position:  destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    setState(() {
      markerSet.add(originMarker);
      markerSet.add(destinationMarker);
    });

    Circle originCircle = Circle(
      circleId: CircleId("originID"),
      fillColor: Colors.green,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: originLatLng
    );

    Circle destinationCircle = Circle(
        circleId: CircleId("destinationID"),
        fillColor: Colors.green,
        radius: 12,
        strokeWidth: 3,
        strokeColor: Colors.white,
        center: destinationLatLng
    );
    setState(() {
      circleSet.add(originCircle);
      circleSet.add(destinationCircle);
    });
  }

  void showSuggestedRideContainer(){
    setState(() {
      suggestedRidesContainerHeight = 400;
      bottomPaddingOfMap = 400;
    });
  }


  //if LocationPermission.denied then set _locationPermission to Geolocator.requestPermission()
  checkIfLocationPermissionAllowed() async{
    _locationPermission = await Geolocator.requestPermission();
    if(_locationPermission == LocationPermission.denied){
      _locationPermission = await Geolocator.requestPermission();
    }
  }


  @override
  void initState() {
    super.initState();
    checkIfLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme = MediaQuery.of(context).platformBrightness == Brightness.dark;
    return GestureDetector(
      onTap: (){FocusScope.of(context).unfocus();},
      child: Scaffold(
        key: _scaffoldState,
        body: Stack(
          children: [
            GoogleMap(
              padding: EdgeInsets.only(top: 30, bottom: bottomPaddingOfMap),
              mapType: MapType.normal,
              myLocationEnabled: true,
              // myLocationButtonEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              initialCameraPosition: _kGooglePlex,
              polylines: polylineSet,
              markers: markerSet,
              circles: circleSet,
              onMapCreated: (GoogleMapController controller){
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;



                setState(() {
                  bottomPaddingOfMap = 200;
                });
                locateUserPosition();
              },

            ),


            //Ui for searching location
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 50, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: darkTheme ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(5),
                            child: Row(
                              children: [
                                Icon(Icons.location_on_outlined, color: darkTheme ? Colors.amber[400] : Colors.blue,),
                                SizedBox(width: 10,),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("From",
                                        style: TextStyle(
                                          color: darkTheme ? Colors.amber[400] : Colors.blue,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      Text(
                                          Provider.of<AppInfo>(context).userPickUpLocation != null
                                              ? Provider.of<AppInfo>(context).userPickUpLocation!.locationName!
                                              : "Not Getting Address",
                                          style: TextStyle(color: Colors.grey, fontSize: 14),
                                          softWrap: false,
                                          overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 5,),
                          Divider(
                            height: 1,
                            thickness: 2,
                            color: darkTheme ? Colors.amber[400] : Colors.blue,
                          ),
                          SizedBox(height: 5,),

                          Padding(
                            padding: EdgeInsets.all(5),
                            child: GestureDetector(
                              onTap: () async{
                                //go to search places screen
                                var responseFromSearchScreen = await Navigator.push(context, MaterialPageRoute(builder: (c) => SearchPlacesScreen()));
                                if(responseFromSearchScreen == "obtainedDropoff"){
                                  setState(() {
                                    openNavigationDrawer = false;
                                  });
                                }
                                await drawPolyLineFromOriginToDestination(darkTheme);
                              },
                              child: Row(
                                children: [
                                  Icon(Icons.location_on_outlined, color: darkTheme ? Colors.amber[400] : Colors.blue,),
                                  SizedBox(width: 10,),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("To",
                                        style: TextStyle(
                                            color: darkTheme ? Colors.amber[400] : Colors.blue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold
                                        ),
                                      ),
                                      Text(
                                        Provider.of<AppInfo>(context).userDropOffLocation != null
                                            ?Provider.of<AppInfo>(context).userDropOffLocation!.locationName!
                                            : "Where to?",
                                        style: TextStyle(color: Colors.grey, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: 5,),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                  onPressed: (){
                                    // Navigator.push(context, MaterialPageRoute(builder: (c)=>PricePickUpScreen()));
                                  },
                                  child: Text(
                                    "Change Pick Up Address",
                                    style: TextStyle(
                                      color: darkTheme ? Colors.black : Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    primary: darkTheme ? Colors.amber[400] : Colors.blue,
                                    textStyle: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16
                                    )
                                  ),
                              ),

                              SizedBox(width: 10,),
                              ElevatedButton(
                                onPressed: (){
                                  if(Provider.of<AppInfo>(context, listen: false).userDropOffLocation != null){
                                    showSuggestedRideContainer();
                                  }
                                  else{
                                    Fluttertoast.showToast(msg: "Please select destination location");
                                  }
                                },
                                child: Text(
                                  "Show Fare",
                                  style: TextStyle(
                                    color: darkTheme ? Colors.black : Colors.white,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                    primary: darkTheme ? Colors.amber[400] : Colors.blue,
                                    textStyle: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16
                                    )
                                ),
                              ),

                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),

      ),
    );
  }
}
