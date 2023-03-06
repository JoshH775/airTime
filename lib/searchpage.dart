import 'package:flutter/material.dart';
import 'server.dart';

class searchPage extends StatefulWidget {
  final List<Flight> flights;

  const searchPage({Key? key, required this.flights}) : super(key: key);

  @override
  State<searchPage> createState() => _searchPageState();
}

class _searchPageState extends State<searchPage> {

  void listToWidgets(List<Flight> list){
    setState(() {
      suggestionsWidgets = [];
      for (Flight item in list){
        suggestionsWidgets.add(Padding(padding: EdgeInsets.all(3), child: ElevatedButton(onPressed: (){Navigator.pop(context, item);}, child: Text(item.callSign.toString()))));
      }
    });

  }

  void search(String text, List<Flight> list) {
    List<Flight> toRemove = [];
    suggestions=list;
    for (Flight item in suggestions){
      if(item.callSign.toString().toLowerCase().contains(text)==false){
        toRemove.add(item);
      }

      var setSuggestions = Set.from(suggestions);
      var setToRemove = Set.from(toRemove);
      suggestions=List.from(setSuggestions.difference(setToRemove));

      listToWidgets(suggestions);

    }
  }

  List<Flight> suggestions = [];
  List<Widget> suggestionsWidgets = [];

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) =>
    (suggestions = widget.flights));
  }

  @override
  Widget build(BuildContext context) {
    print(suggestions);
    return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: Column(children: [
          TextField(onChanged: (text) {search(text, widget.flights);}, decoration: InputDecoration(hintText: "Search for callsign/icao24:")),
          Expanded(child: Container(child: ListView(children: suggestionsWidgets,)))

        ])));
  }
}




