import 'package:flutter/cupertino.dart';

import 'server.dart';
import 'package:flutter/services.dart';

void main(){
  WidgetsFlutterBinding.ensureInitialized();
  Server().requestAirports();
}