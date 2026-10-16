import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:Orvia/utils/load_image.dart';

Future<PaletteGenerator> getPalleteFromImage(String url) async {
  ImageProvider<Object> placeHolder =
      const AssetImage("assets/icons/OrviaLogo_System.png");

  try {
    return await PaletteGenerator.fromImageProvider(
      getImageProviderSync(url),
    );
  } catch (e) {
    return await PaletteGenerator.fromImageProvider(placeHolder);
  }
}
