import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paskluis_v1/data/templates/card_templates.dart';
import 'package:paskluis_v1/data/services/brand_recognition.dart';
void main() {
  const ah = CardBrandTemplate(id:'ah',name:'Albert Heijn',logoAsset:'',color:Colors.blue,searchTerms:['AH'],recognitionKeywords:['Bonuskaart'],barcodePrefixes:['2620']);
  const gall = CardBrandTemplate(id:'gall',name:'Gall & Gall',logoAsset:'',color:Colors.orange,barcodePrefixes:['6064']);
  test('uses managed aliases and recognition words with word boundaries', () {
    expect(BrandRecognition.match([ah,gall],text:'Mijn Bonuskaart',code:''),ah);
    expect(BrandRecognition.match([ah,gall],text:'AH',code:''),ah);
    expect(BrandRecognition.match([ah,gall],text:'Sahara',code:''),isNull);
    expect(BrandRecognition.match([ah,gall],text:'Gall & Gall',code:''),gall);
  });
  test('uses unique barcode prefix but never guesses on conflicting evidence', () {
    expect(BrandRecognition.match([ah,gall],text:'',code:'2620123456789'),ah);
    expect(BrandRecognition.match([ah,gall],text:'Albert Heijn en Gall & Gall',code:'2620123456789'),isNull);
    const other=CardBrandTemplate(id:'other',name:'Other',logoAsset:'',color:Colors.red,barcodePrefixes:['2620']);
    expect(BrandRecognition.match([ah,other],text:'',code:'2620123456789'),isNull);
  });
}
