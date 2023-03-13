import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'searchpage.dart';
import 'server.dart';
import 'dart:ui' as ui;
//TODO
//1. Set minmax zoom
Server server = Server();

Future<Uint8List?> getIconBytes(String assetPath, width) async{
  ByteData assetData = await rootBundle.load(assetPath);
  var codec = await ui.instantiateImageCodec(assetData.buffer.asUint8List(),targetWidth: width);
  ui.FrameInfo frameInfo = await codec.getNextFrame();
  return (await frameInfo.image.toByteData(format: ui.ImageByteFormat.png))?.buffer.asUint8List();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    home: home(),
    debugShowCheckedModeBanner: false,
  ));
}

class home extends StatefulWidget {
  const home({Key? key}) : super(key: key);


  @override
  State<home> createState() => homeState();
}

class homeState extends State<home> {

  late GoogleMapController mapController;
  String searchText = "Search";
  late String mapStyle;
  late Future<String> responseStatus;
  List<Flight> flights = [];
  static const CameraPosition heathrow = CameraPosition(zoom: 5.917, target: LatLng(54.37621992593971, -1.9079618901014328));
  List<Marker> markers = [];
  List<Airport> airports = [];
  bool airportsVisible = false;



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    rootBundle
        .loadString('assets/map-style.txt')
        .then((string) => {mapStyle = string});
    responseStatus=getFlights();
    getAirports();



  }

  void getAirports(){
    setState((){
      airportsVisible=true;
      for (Airport airport in airports){
        Marker airportMarker = Marker(
          markerId: MarkerId(airport.gps+"- Airport"),
          position: LatLng(airport.lattitude,airport.longitude),
          infoWindow: InfoWindow(title: airport.name)
        );
        markers.add(airportMarker);
      }
    });

  }

  void search() async {
    String responseText = "";
    var result = await Navigator.push(context, MaterialPageRoute(builder: (context) => searchPage(searchData: [flights,airports])));
    getAirports();
    print(result.runtimeType);
    setState(() {
      if (result.runtimeType == Airport){
        searchText=result.gps;
        responseText=result.gps;
        print(responseText);
      }
      else{
        searchText=result.callSign;
        responseText=result.callSign;
      }
    });
    print("here");
    for (Marker marker in markers){
      print(marker.markerId.value);
      if (marker.markerId.value.contains(responseText)==true){
        mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: marker.position,zoom: 10)));
        mapController.showMarkerInfoWindow(marker.markerId);
      }
    }
  }

  void airportToggle(){
    if (airportsVisible==true){
      setState(() {
        airportsVisible=false;
        List<Marker> toRemove = [];
        for (Marker marker in markers){
          if (marker.markerId.value.contains("Airport")){
            toRemove.add(marker);
          }
        }
        var markersSet = Set.from(markers);
        var airportsSet = Set.from(toRemove);
        markers=List.from(markersSet.difference(airportsSet));
      });
    }else{
      setState(() {
        airportsVisible=true;
        getAirports();
      });
    }
  }

  Future<String> getFlights() async {
    final icon = await BitmapDescriptor.fromBytes(await getIconBytes("assets/flight.png",55) as Uint8List);
    List<Flight> response = await server.requestFlights();
    if (response.length > 0) {
      setState(() {
        flights = response;
        for (var flight in flights) {
          Marker flightMarker = Marker(
              icon: icon,
              rotation: flight.heading as double,
              markerId: MarkerId(flight.callSign.toString()),
              position:
              LatLng(flight.lattitude as double, flight.longitude as double),
              infoWindow: InfoWindow(
                  title:
                  "${flight.callSign.toString()}"));
          markers.add(flightMarker);

        }
      });
      return "Successful";
    }else{
      return "Unsuccessful";
    }

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        body: Stack(children: [
          Align(
              alignment: Alignment.center,
              child: Container(
                  child: GoogleMap(

                    rotateGesturesEnabled: false,
                    initialCameraPosition: heathrow,
                    zoomControlsEnabled: false,
                    mapType: MapType.satellite,
                    cameraTargetBounds: CameraTargetBounds(LatLngBounds(southwest: LatLng(49.662111, -6.144732), northeast: LatLng(61.062128, -0.1557970))),
                    onMapCreated: (GoogleMapController controller) {
                      setState(() async {
                        mapController = controller;
                        airports=await server.requestAirports();
                      });
                    },
                    onCameraMove: (CameraPosition position) {
                      print("${position.target} ${position.zoom}");
                    },
                    markers: Set<Marker>.of(markers),
                  ))),
          Align(
              alignment: const Alignment(0, 0.9),
              child: ElevatedButton.icon(
                onPressed: (){setState(() {
                  responseStatus=getFlights();
                });},
                icon: const Icon(
                  Icons.refresh,
                  size: 31,
                ),
                label: const Text(
                  style: TextStyle(fontSize: 20),
                  "Refresh",
                  textAlign: TextAlign.center,
                ),
                style: ElevatedButton.styleFrom(
                    shadowColor: Colors.black,
                    fixedSize: Size(MediaQuery.of(context).size.width * 0.5, 50),
                    shape: const StadiumBorder()),
              )),

          Align(
              alignment: Alignment(0, -0.87),
              child: ElevatedButton.icon(
                onPressed: () {search();},
                icon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                ),
                label: Text(
                  searchText,
                  style: const TextStyle(color: Colors.grey),
                ),
                style: ElevatedButton.styleFrom(
                    fixedSize: Size(MediaQuery.of(context).size.width * 0.45,
                        MediaQuery.of(context).size.height * 0.07),
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      side: BorderSide(width: 2, color: Colors.black),
                      borderRadius: BorderRadius.all(Radius.circular(50)),
                    )),
              )),

          FutureBuilder(future: responseStatus, builder: (context,snapshot){
            if (snapshot.connectionState==ConnectionState.waiting){
              return const Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator());
            }else if (snapshot.data==null){
              return Padding(padding: EdgeInsets.all(5),child: Align(alignment: Alignment.bottomCenter, child: Text("Response: Unsuccessful")));
            }else{
              return Padding(padding: EdgeInsets.all(5),child: Align(alignment: Alignment.bottomCenter, child: Text("Response: ${snapshot.data}")));
            }
          }),

          Padding(padding: EdgeInsets.all(10), child: Align(alignment: Alignment.bottomLeft, child: FloatingActionButton(heroTag: "airports", child: Icon(Icons.flight_takeoff), onPressed: () { setState(() {
            print(airportsVisible);
            airportToggle();
          });},
          ))),

          Padding(padding: EdgeInsets.all(10), child: Align(alignment: Alignment.bottomRight, child: FloatingActionButton(heroTag: "location", onPressed: () {  },
          child: Icon(Icons.my_location))))

        ]));
  }
}
