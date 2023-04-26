import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'searchpage.dart';
import 'server.dart';
import 'dart:ui' as ui;

Server server = Server();

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
  static const CameraPosition heathrow = CameraPosition(
      zoom: 5.917,
      target: LatLng(
          54.37621992593971, -1.9079618901014328)); //initail camera position
  List<Marker> markers = [];
  List<Airport> airports = [];
  bool airportsVisible = false;
  bool selected = false;
  Flight? selectedFlight = null;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    responseStatus = getFlights();
    getAirports();
  }

//function to animate the camera to the user's position
  void getPosition() async {
    LatLng location = await server.getLocation();
    setState(() {
      Marker locationMarker = Marker(
          markerId: const MarkerId("Location"),
          position: location,
          infoWindow: const InfoWindow(title: "User"));
      markers.add(locationMarker);
      mapController.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: location, zoom: 11)));
      mapController.showMarkerInfoWindow(const MarkerId("Location"));
    });
  }

  Future<String> getFlights() async {
    List<Flight> response = await server.requestFlights();

    final icon = await BitmapDescriptor.fromBytes(
        await getIconBytes("assets/flight.png", 55) as Uint8List);
    if (response.isNotEmpty) {
      setState(() {
        flights = response;
        for (var flight in flights) {
          // List<String> metadata = await server.getModel(flight.icao24);
          Marker flightMarker = Marker(
              icon: icon,
              onTap: () {
                setState(() {
                  selected = false;
                  selectedFlight = flight;
                  print(selectedFlight);
                });
              },
              rotation: flight.heading as double,
              markerId: MarkerId(flight.callSign.toString()),
              position: LatLng(
                  flight.lattitude as double, flight.longitude as double),
              infoWindow: InfoWindow(title: flight.callSign.toString()));
          markers.add(flightMarker);
        }
      });
      return "Successful";
    } else {
      return "Unsuccessful";
    }
  }

  void getAirports() {
    //Draws markers onto the map
    setState(() {
      airportsVisible = true;
      for (Airport airport in airports) {
        Marker airportMarker = Marker(
            markerId: MarkerId("${airport.gps}- Airport"),
            position: LatLng(airport.lattitude, airport.longitude),
            infoWindow: InfoWindow(title: airport.name));
        markers.add(airportMarker);
      }
    });
  }

  void search() async {
    //When search bar is pressed
    String responseText = "";
    var result = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => searchPage(searchData: [
                  flights,
                  airports
                ]))); //Goes to search page and comes back with clicked marker
    getAirports(); //makes airports visible again incase they searched for an airport

    setState(() {
      if (result.runtimeType == Airport) {
        //If search results is airport
        searchText = result.gps;
        responseText = result.gps;
        print(responseText);
      } else {
        //otherwise the search results is a flight
        searchText = result.callSign;
        responseText = result.callSign;
      }
    });

    for (Marker marker in markers) {
      if (marker.markerId.value.contains(responseText) == true) {
        //searches for an existing marker to navigate the camera to
        mapController.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(target: marker.position, zoom: 10)));
        mapController.showMarkerInfoWindow(marker.markerId);
      }
    }
  }

  void airportToggle() {
    if (airportsVisible == true) {
      setState(() {
        airportsVisible = false;
        List<Marker> toRemove = [];
        for (Marker marker in markers) {
          //removes all markers that relate to airports
          if (marker.markerId.value.contains("Airport")) {
            toRemove.add(marker);
          }
        }
        var markersSet = Set.from(markers);
        var airportsSet = Set.from(toRemove);
        markers = List.from(markersSet.difference(airportsSet));
      });
    } else {
      setState(() {
        airportsVisible = true;
        getAirports();
      });
    }
  }

  Future<Uint8List?> getIconBytes(String assetPath, width) async {
    ByteData assetData = await rootBundle.load(assetPath);
    var codec = await ui.instantiateImageCodec(assetData.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo frameInfo = await codec.getNextFrame();
    return (await frameInfo.image.toByteData(format: ui.ImageByteFormat.png))
        ?.buffer
        .asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Stack(children: [
      //MAPS WIDGET
      Align(
          alignment: Alignment.center,
          child: Container(
              child: GoogleMap(
            rotateGesturesEnabled: false,
            initialCameraPosition: heathrow,
            zoomControlsEnabled: false,
            mapType: MapType.satellite,
            //cameraTargetBounds: CameraTargetBounds(LatLngBounds(southwest: const LatLng(49.662111, -6.144732), northeast: const LatLng(61.062128, -0.1557970))),
            onMapCreated: (GoogleMapController controller) async {
              var syncAirports = await server.requestAirports();
              setState(() {
                mapController = controller;
                airports = syncAirports;
              });
            },
            onTap: ((argument) {
              setState(() {
                selected = false;
              });
            }),
            onCameraMove: (CameraPosition position) {
              // print("${position.target} ${position.zoom}");
            },
            markers: Set<Marker>.of(markers),
          ))),

      //REFRESH BUTTON
      Align(
          alignment: const Alignment(0, 0.9),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                responseStatus = getFlights();
              });
            },
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

      //SEARCH BUTTON
      Align(
          alignment: const Alignment(0, -0.87),
          child: ElevatedButton.icon(
            onPressed: () {
              search();
            },
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

      //CIRCULAR PROGRESS INDICATOR
      FutureBuilder(
          future: responseStatus,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator());
            } else if (snapshot.data == null) {
              return const Padding(
                  padding: EdgeInsets.all(5),
                  child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text("Response: Unsuccessful")));
            } else {
              return Padding(
                  padding: const EdgeInsets.all(5),
                  child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Text("Response: ${snapshot.data}")));
            }
          }),

      CustomInfoWindow(selected: selected, flight: selectedFlight),

      //AIRPORTS BUTTON
      Padding(
          padding: const EdgeInsets.all(10),
          child: Align(
              alignment: Alignment.bottomLeft,
              child: FloatingActionButton(
                heroTag: "airports",
                child: const Icon(Icons.flight_takeoff),
                onPressed: () {
                  setState(() {
                    airportToggle();
                  });
                },
              ))),

      //LOCATION BUTTON
      Padding(
          padding: const EdgeInsets.all(10),
          child: Align(
              alignment: Alignment.bottomRight,
              child: FloatingActionButton(
                  heroTag: "location",
                  onPressed: () {
                    getPosition();
                  },
                  child: const Icon(Icons.my_location))))
    ]));
  }
}

class CustomInfoWindow extends StatefulWidget {
  CustomInfoWindow({super.key, required this.selected, this.flight});
  bool selected;
  Flight? flight;

  @override
  State<CustomInfoWindow> createState() => _CustomInfoWindowState();
}

class _CustomInfoWindowState extends State<CustomInfoWindow> {



  @override
  Widget build(BuildContext context) {
      print(widget.flight);
      print("here");
    return AnimatedContainer(
        duration: Duration(milliseconds: 250),
        alignment: widget.selected ? Alignment(0, -0.65) : Alignment(0.9, -0.9),
        curve: Curves.fastOutSlowIn,
        child: GestureDetector(
          onTap: () {
            setState(() {
              widget.selected = !widget.selected;
            });
          },
          child: AnimatedContainer(
            decoration: BoxDecoration(
                borderRadius: widget.selected
                    ? BorderRadius.circular(20)
                    : BorderRadius.circular(100),
                color: Colors.white,
                border: Border.all(width: 2.0, color: Colors.black)),
            duration: const Duration(milliseconds: 100),
            width: widget.selected
                ? MediaQuery.of(context).size.width * 0.8
                : MediaQuery.of(context).size.width * 0.15,
            height: widget.selected
                ? MediaQuery.of(context).size.height * 0.15
                : MediaQuery.of(context).size.width * 0.15,
            child: widget.selected
                ?  FutureBuilder(future: selectedChildren(context), builder: ((context, snapshot) {
                  if (snapshot.hasData){
                    return snapshot.data as Widget;
                  }
                  else{
                    return Center(
              child: CircularProgressIndicator());
                  }
                  
                }))
                : Center(child: Text("i")),
          ),
        ));
  }

  Future<Widget> selectedChildren(BuildContext context) async{
    if (widget.flight != null){
      List<String> modelInfo = await server.getModel(widget.flight?.icao24 as String);
  return Column(children: [
        Padding(
          padding: const EdgeInsets.all(5.0),
          child: Text("${widget.flight?.callSign?.trim()}/${widget.flight?.icao24}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 21),),
        ),
                Text("Model: ${modelInfo[0]}"),
                Text("Operator: ${modelInfo[1]}"),
                Text("Altitude: ${widget.flight!.baroAltitude}M"),
                Text("Last Contact: ${DateTime.fromMillisecondsSinceEpoch(widget.flight!.lastContact*1000)}")

    ]);
    }else{
      return Center(child: Text("No flight selected!"));
    }
    
  }
}
