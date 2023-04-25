// * [
// * 0 icao24: string,
// * 1 callsign: string (nullable),
// * 2 originCountry: string,
// * 3 lastPositionUpdate: int (nullable),
// * 4 lastContact: int,
// * 5 longitude: float #.#### (nullable),
// * 6 latitude: float #.#### (nullable),
// * 7 baroAltitude: float #.## (nullable),
// * 8 isOnGround: bool,
// * 9 velocityOverGround: float #.## (nullable),
// * 10 heading: float #.## (nullable),
// * 11 verticalRate: float #.## (nullable),
// * 12 sensorSerials: Array[int] (nullable),
// * 13 geoAltitude: float #.## (nullable),
// * 14 squawk: string (nullable),
// * 15 isAlert: bool,
// * 17 positionSource: int 0 for ADS-B, 1 for Asterix, 2 for MLAT
// * ]

//Flight newFlight = Flight(flight[0],flight[1],flight[2],flight[3],flight[4],flight[5],flight[6],flight[7],flight[8],flight[9],flight[10],flight[11],flight[12],flight[13],flight[14],flight[15],flight[16]);
import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

List<double> mincoord=[49.662111, -6.144732]; //bottom left of the uk
List<double> maxcoord=[61.062128, -0.1557970]; //top right of uk

class Flight {
  String icao24;
  String? callSign;
  String originCountry;
  int? lastPositionUpdate;
  int lastContact;
  double? longitude;
  double? lattitude;
  double? baroAltitude;
  bool onGround;
  double? velocityOverGround;
  double? heading;
  double? verticalRate;
  List<dynamic>? sensorSerials;
  double? geoAltitude;
  String? squawk;
  bool isAlert;
  int positionSource;


  Map toMap() => {'icao24':icao24,'Callsign':callSign,'Manufacturing Country':originCountry,'Last Position Update':lastPositionUpdate,'Last Contact':lastContact,'Longitude':longitude,'Lattitude':lattitude,'Baro Altitude':baroAltitude,'On Ground?':onGround,'Velocity over ground':velocityOverGround,'Heading':heading,'Vertical rate':verticalRate,'Sensor Serials':sensorSerials,'Geo. Altitude':geoAltitude,'Squawk':squawk,'Is Alert?':isAlert,'Position Source':positionSource};

  List<dynamic> toList() => [icao24,callSign,originCountry,lastPositionUpdate,lastContact,longitude,lattitude,baroAltitude,onGround,velocityOverGround,heading,verticalRate,sensorSerials,geoAltitude,squawk,isAlert,positionSource];

  @override
  String toString() {
    return '$icao24, $callSign, $originCountry, $lastPositionUpdate, $lastContact, $longitude, $lattitude, $baroAltitude, $onGround, $velocityOverGround, $heading, $verticalRate, $sensorSerials, $geoAltitude, $squawk, $isAlert, $positionSource ';
  }

  Flight( this.icao24, this.callSign, this.originCountry, this.lastPositionUpdate, this.lastContact, this.longitude, this.lattitude, this.baroAltitude, this.onGround, this.velocityOverGround, this.heading, this.verticalRate, this.sensorSerials, this.geoAltitude, this.squawk, this.isAlert,this.positionSource);
  
}

class Airport{
  String name;
  String gps;
  String icao;
  double lattitude;
  double longitude;

  Airport(this.name, this.gps, this.icao, this.lattitude, this.longitude);

  @override
  String toString() {
    return 'Airport { name: $name, gps: $gps, icao: $icao, lattitude: $lattitude, longitude: $longitude}';
  }

  Airport.fromCSVLine(List<dynamic> line):
      name=line[3],
      gps=line[12],
      icao=line[13],
      lattitude=line[4],
      longitude=line[5];

}

class Server{

  Future<LatLng> getLocation() async { //https://pub.dev/packages/geolocator
    bool services = false;
    LocationPermission permissions;
    services = await Geolocator.isLocationServiceEnabled(); //Device's gps services
    if (services==false){
      return Future.error("Not enabled");
    }

    permissions = await Geolocator.checkPermission(); //Once services are on, check if app has permissions already
    if (permissions == LocationPermission.denied){
      permissions = await Geolocator.requestPermission(); //Ask for permissions
      if (permissions == LocationPermission.denied){ //No perms for us :(
        return Future.error("Perms denied");
      }
    }

    if (permissions == LocationPermission.deniedForever){
      return Future.error("Denied forever");
    }

    Position currentPosition = await Geolocator.getCurrentPosition();
    return LatLng(currentPosition.latitude, currentPosition.longitude);

  }



  List<dynamic> nullCheck(flightAsList){ //function to set a null value to its data type's default
    List<dynamic> errorFallback = ['N/A','N/A','N/A',0,0,0.0,0.0,0.0,false,0.0,0.0,0.0,[0],0.0,'N/A',false,0,'N/A'];
    for (int i=0;i<flightAsList.length;i++){
      if (flightAsList[i]==null){
        flightAsList[i]=errorFallback[i];
      }
    }
    return flightAsList;
  }

  // List<Flight> fromJson() async{
  //   File file = File('snapshot.json');
  //   var readJson = json.decode(file.readAsStringSync());;
  //   List<Flight> flightlist=[];

  //   for (Map item in readJson){ //turning each map in the json to a flight
  //     List<dynamic> flight = nullCheck(item.values.toList());
  //     Flight newFlight = Flight(flight[0],flight[1],flight[2],flight[3],flight[4],flight[5],flight[6],flight[7],flight[8],flight[9],flight[10],flight[11],flight[12],flight[13],flight[14],flight[15],flight[16],await DBProvider().getModel(flight[0]));
  //     flightlist.add(newFlight);
  //     }

  //   return flightlist;
  //   }

  Future<List<Flight>> requestFlights() async{
    var response;
    try{
      String rawCredentials = await PlatformAssetBundle().loadString("assets/credentials.txt");
      List<String> credentials=rawCredentials.split("\n");

      response=await http.get(Uri.parse('https://${credentials[0].trim()}:${credentials[1].trim()}@opensky-network.org/api/states/all?lamin=${mincoord[0]}&lomin=${mincoord[1]}&lamax=${maxcoord[0]}&lomax=${maxcoord[1]}'));

    }catch (e){
      print(e);
      response=await http.get(Uri.parse('https://opensky-network.org/api/states/all?lamin=${mincoord[0]}&lomin=${mincoord[1]}&lamax=${maxcoord[0]}&lomax=${maxcoord[1]}'));
    }

    // print(response.statusCode);
    // print(response.request);
  
    final Map parsed = jsonDecode(response.body.toString());
    
    List<Flight> flightList=[];
    
    for (var single in parsed['states']){
      List<dynamic> flight=nullCheck(single);
      String icao24 = flight[0];
      String? callSign = flight[1];
      String originCountry = flight[2];
      int? lastPositionUpdate = flight[3];
      int lastContact = flight[4];
      double? longitude = double.parse(flight[5].toString());
      double? lattitude = double.parse(flight[6].toString());
      double? baroAltitude = double.parse(flight[7].toString());
      bool onGround = flight[8];
      double? velocityOverGround = double.parse(flight[9].toString());
      double? heading = double.parse(flight[10].toString());
      double? verticalRate = double.parse(flight[11].toString());
      List<int>? sensorSerials = flight[12];
      double? geoAltitude = double.parse(flight[13].toString());
      String? squawk = flight[14];
      bool isAlert = flight[15];
      int positionSource = flight[16];
      
      
      Flight newflight=Flight(icao24, callSign, originCountry, lastPositionUpdate, lastContact, longitude, lattitude, baroAltitude, onGround, velocityOverGround, heading, verticalRate, sensorSerials, geoAltitude, squawk, isAlert, positionSource);
      flightList.add(newflight);
      
    }


    return flightList;
  }

  Future<List<Airport>> requestAirports() async{
    List<Airport> airports = [];
    String raw = await PlatformAssetBundle().loadString("assets/GBAirports.csv");
    List<List<dynamic>> csv = CsvToListConverter().convert(raw);

    for (int i = 0; i < csv.length; i++){
      airports.add(Airport.fromCSVLine(csv[i]));
    }
    return airports;
  }
}

class DBProvider {
  Future<Database> openDB() async {
    Directory dir =
        await getApplicationDocumentsDirectory(); //Checks where the app is installed for the database
    String path = join(dir.path, 'lists.db');

    if (await databaseExists(path) == false) {
      //If not found (likely first install), load from apk.
      ByteData data = await rootBundle.load(join("assets", "lists.db"));
      List<int> bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await File(path).writeAsBytes(bytes, flush: true);

      return await openDatabase(path);
    } else {
      return await openDatabase(path);
    }
  }

  Future<dynamic> getModel(String icao24) async{
    Database db = await openDB();
    var make = await db.rawQuery("SELECT manufacturername || ' ' || model from aircraft where icao24 = '$icao24'");
    return make;

  }
}