/// Classi base dell'architettura MVVM (1 Screen : 1 ViewModel).
///
/// Una sola libreria con più `part`: `BaseScreenState` e `BaseViewModel`
/// condividono membri privati (visibilità, inizializzazione) e devono restare
/// nella stessa libreria.
library;

import 'dart:async';

import 'package:app_result/app_result.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

part '../src/architectural_components_config.dart';
part '../src/architectural_layers.dart';
part '../src/base_screen_state.dart';
part '../src/base_view_model.dart';
part '../src/edge_swipe_back_guard.dart';
part '../src/failure_handler.dart';
part '../src/ui_request.dart';
