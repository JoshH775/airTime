import 'package:airtime/main.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'server.dart';

class searchPage extends StatefulWidget {
  final List<dynamic> searchData;

  const searchPage({Key? key, required this.searchData}) : super(key: key);

  @override
  State<searchPage> createState() => _searchPageState();
}

class _searchPageState extends State<searchPage> {


  void listToWidgets(List<dynamic> list){
    setState(() {
      suggestionsWidgets = [];
      for (var item in list){

        if (item.runtimeType == Airport){

          suggestionsWidgets.add(Padding(padding: EdgeInsets.all(3), child: ElevatedButton(onPressed: (){Navigator.pop(context, item);}, child: Text("${item.name} / ${item.gps}"))));
        }else{
          suggestionsWidgets.add(Padding(padding: EdgeInsets.all(3), child: ElevatedButton(onPressed: (){Navigator.pop(context, item);}, child: Text(item.callSign.toString()))));
        }
      }

    });

  }

  void search(String text, List<dynamic> list) {
    List<dynamic> toRemove = [];
    suggestions=list;
    print(suggestions.length);
    for (var item in suggestions){
      if (item.runtimeType==Flight){
        if(item.callSign.toString().toLowerCase().contains(text)==false){
          toRemove.add(item);
        }
      }else{
        if (item.name.toLowerCase().contains(text)==false && item.gps.toLowerCase().contains(text)==false && item.icao.toLowerCase().contains(text)==false){
          toRemove.add(item);
        }
      }

      var setSuggestions = Set.from(suggestions);
      var setToRemove = Set.from(toRemove);
      suggestions=List.from(setSuggestions.difference(setToRemove));

      listToWidgets(suggestions);

    }
  }

  List<dynamic> suggestions = [];
  List<Widget> suggestionsWidgets = [];
  List<dynamic> searchables = [];

  @override
  void initState(){
    // TODO: implement initState
    super.initState();
    searchables.addAll(widget.searchData[0]);
    searchables.addAll(widget.searchData[1]);
  }

  @override
  Widget build(BuildContext context) {
    print(suggestions);
    return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: Column(children: [
          TextField(onChanged: (text) {search(text, searchables);}, decoration: InputDecoration(hintText: "Search for callsign/icao24:")),
          Expanded(child: Container(child: ListView(children: suggestionsWidgets,)))

        ])));
  }
}




