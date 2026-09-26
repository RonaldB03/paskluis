/// Format generic device labels, including labels saved in an older locale.
/// Custom device names remain unchanged.
String deviceDescription(String name, {required bool dutch}) {
  switch (name.trim().toLowerCase()) {
    case 'android-apparaat':
    case 'android device':
      return dutch ? 'een Android-apparaat' : 'an Android device';
    case 'iphone of ipad':
    case 'iphone or ipad':
      return dutch ? 'een iPhone of iPad' : 'an iPhone or iPad';
    case 'windows-apparaat':
    case 'windows device':
      return dutch ? 'een Windows-apparaat' : 'a Windows device';
    case 'mac':
      return dutch ? 'een Mac' : 'a Mac';
    case '':
    case 'ander apparaat':
    case 'een ander apparaat':
    case 'another device':
      return dutch ? 'een ander apparaat' : 'another device';
    default:
      return name.trim();
  }
}
