/// Lightweight trilingual string table (NF3: Sinhala, Tamil, English).
///
/// Patient-facing screens are fully translated. Staff screens use English
/// because the OPD staff surveyed in Milestone 01 work in English-language
/// registers (documented as a deviation in the report).
class S {
  static const supported = ['en', 'si', 'ta'];
  static const languageNames = {'en': 'English', 'si': 'සිංහල', 'ta': 'தமிழ்'};

  /// Every translation key (used by the test that checks all three languages).
  static List<String> get allKeys => _t.keys.toList();

  static String of(String lang, String key) => _t[key]?[lang] ?? _t[key]?['en'] ?? key;

  static const Map<String, Map<String, String>> _t = {
    'appName': {'en': 'OPD Connect', 'si': 'OPD Connect', 'ta': 'OPD Connect'},
    'home': {'en': 'Home', 'si': 'මුල් පිටුව', 'ta': 'முகப்பு'},
    'appointments': {'en': 'Appointments', 'si': 'වේලාවන්', 'ta': 'சந்திப்புகள்'},
    'notifications': {'en': 'Notifications', 'si': 'දැනුම්දීම්', 'ta': 'அறிவிப்புகள்'},
    'settings': {'en': 'Settings', 'si': 'සැකසුම්', 'ta': 'அமைப்புகள்'},
    'hello': {'en': 'Hello', 'si': 'ආයුබෝවන්', 'ta': 'வணக்கம்'},
    'bookAppointment': {'en': 'Book appointment', 'si': 'වේලාවක් වෙන් කරන්න', 'ta': 'சந்திப்பை பதிவு செய்யவும்'},
    'nextAppointment': {'en': 'Your next appointment', 'si': 'ඔබගේ ඊළඟ වේලාව', 'ta': 'உங்கள் அடுத்த சந்திப்பு'},
    'viewLiveQueue': {'en': 'View live queue', 'si': 'සජීවී පෝලිම බලන්න', 'ta': 'நேரலை வரிசையைப் பார்க்கவும்'},
    'noUpcoming': {
      'en': 'You have no upcoming appointments.',
      'si': 'ඔබට ඉදිරි වේලාවන් නොමැත.',
      'ta': 'உங்களுக்கு வரவிருக்கும் சந்திப்புகள் இல்லை.'
    },
    'step': {'en': 'Step', 'si': 'පියවර', 'ta': 'படி'},
    'chooseHospital': {'en': 'Choose a hospital', 'si': 'රෝහලක් තෝරන්න', 'ta': 'மருத்துவமனையைத் தேர்ந்தெடுக்கவும்'},
    'chooseClinic': {'en': 'Choose a clinic', 'si': 'සායනයක් තෝරන්න', 'ta': 'சிகிச்சைப் பிரிவைத் தேர்ந்தெடுக்கவும்'},
    'chooseDay': {
      'en': 'Choose a day and time',
      'si': 'දිනය සහ වේලාව තෝරන්න',
      'ta': 'நாள் மற்றும் நேரத்தைத் தேர்ந்தெடுக்கவும்'
    },
    'lastUsed': {'en': 'Last used', 'si': 'අවසන් වරට භාවිතා කළ', 'ta': 'கடைசியாக பயன்படுத்தியது'},
    'slotsLeft': {'en': 'places left', 'si': 'ඉතිරි ස්ථාන', 'ta': 'இடங்கள் மீதம்'},
    'full': {'en': 'Full', 'si': 'පිරී ඇත', 'ta': 'நிரம்பியது'},
    'today': {'en': 'Today', 'si': 'අද', 'ta': 'இன்று'},
    'tomorrow': {'en': 'Tomorrow', 'si': 'හෙට', 'ta': 'நாளை'},
    'confirmBooking': {'en': 'Confirm booking', 'si': 'වෙන්කිරීම තහවුරු කරන්න', 'ta': 'பதிவை உறுதிப்படுத்தவும்'},
    'bookingConfirmed': {'en': 'Booking confirmed', 'si': 'වෙන්කිරීම තහවුරුයි', 'ta': 'பதிவு உறுதி செய்யப்பட்டது'},
    'yourToken': {'en': 'Your token number', 'si': 'ඔබගේ අංකය', 'ta': 'உங்கள் டோக்கன் எண்'},
    'showAtCounter': {
      'en': 'Show this number at the OPD counter',
      'si': 'මෙම අංකය OPD කවුළුවේදී පෙන්වන්න',
      'ta': 'இந்த எண்ணை OPD கவுண்டரில் காட்டவும்'
    },
    'reference': {'en': 'Booking reference', 'si': 'යොමු අංකය', 'ta': 'பதிவு குறிப்பு'},
    'hospital': {'en': 'Hospital', 'si': 'රෝහල', 'ta': 'மருத்துவமனை'},
    'clinic': {'en': 'Clinic', 'si': 'සායනය', 'ta': 'சிகிச்சைப் பிரிவு'},
    'doctor': {'en': 'Doctor', 'si': 'වෛද්‍යවරයා', 'ta': 'மருத்துவர்'},
    'date': {'en': 'Date', 'si': 'දිනය', 'ta': 'தேதி'},
    'time': {'en': 'Time', 'si': 'වේලාව', 'ta': 'நேரம்'},
    'remindMe': {
      'en': 'Remind me before my visit',
      'si': 'පැමිණීමට පෙර මට මතක් කරන්න',
      'ta': 'வருகைக்கு முன் நினைவூட்டவும்'
    },
    'done': {'en': 'Done', 'si': 'අවසන්', 'ta': 'முடிந்தது'},
    'upcoming': {'en': 'Upcoming', 'si': 'ඉදිරි', 'ta': 'வரவிருப்பவை'},
    'noApptsTitle': {'en': 'No appointments yet', 'si': 'තවම වේලාවන් නොමැත', 'ta': 'இன்னும் சந்திப்புகள் இல்லை'},
    'noApptsBody': {
      'en': 'Book a clinic visit and it will show up here with its live queue.',
      'si': 'සායන වේලාවක් වෙන් කරන්න. එය සජීවී පෝලිම සමඟ මෙහි පෙන්වයි.',
      'ta': 'சிகிச்சை நேரத்தைப் பதிவு செய்தால், நேரலை வரிசையுடன் இங்கே தோன்றும்.'
    },
    'updating': {'en': 'Updating...', 'si': 'යාවත්කාලීන වෙමින්...', 'ta': 'புதுப்பிக்கிறது...'},
    'noPast': {'en': 'No past appointments.', 'si': 'පසුගිය වේලාවන් නොමැත.', 'ta': 'கடந்த சந்திப்புகள் இல்லை.'},
    'past': {'en': 'Past', 'si': 'පසුගිය', 'ta': 'கடந்தவை'},
    'reschedule': {'en': 'Reschedule', 'si': 'දිනය වෙනස් කරන්න', 'ta': 'மாற்றியமைக்கவும்'},
    'cancel': {'en': 'Cancel appointment', 'si': 'වේලාව අවලංගු කරන්න', 'ta': 'சந்திப்பை ரத்து செய்யவும்'},
    'removePermanent': {
      'en': 'This booking will be permanently deleted. This cannot be undone.',
      'si': 'මෙම වෙන්කිරීම සදහටම මකා දමනු ඇත. මෙය ආපසු හැරවිය නොහැක.',
      'ta': 'இந்த பதிவு நிரந்தரமாக நீக்கப்படும். இதை மாற்ற முடியாது.'
    },
    'removeFromList': {'en': 'Remove from list', 'si': 'ලැයිස්තුවෙන් ඉවත් කරන්න', 'ta': 'பட்டியலிலிருந்து நீக்கவும்'},
    'currentBooking': {'en': 'Current booking', 'si': 'වත්මන් වෙන්කිරීම', 'ta': 'தற்போதைய பதிவு'},
    'newDay': {'en': 'Choose the new day', 'si': 'නව දිනය තෝරන්න', 'ta': 'புதிய நாளைத் தேர்ந்தெடுக்கவும்'},
    'confirmChange': {'en': 'Confirm change', 'si': 'වෙනස තහවුරු කරන්න', 'ta': 'மாற்றத்தை உறுதிப்படுத்தவும்'},
    'moveFrom': {'en': 'From', 'si': 'සිට', 'ta': 'இருந்து'},
    'moveTo': {'en': 'To', 'si': 'වෙත', 'ta': 'க்கு'},
    'tokenWillChange': {
      'en': 'Your token number will change when you move to a new day. Your old place is released for another patient.',
      'si': 'නව දිනයකට මාරු වූ විට ඔබගේ අංකය වෙනස් වේ. ඔබගේ පැරණි ස්ථානය වෙනත් රෝගියෙකුට නිදහස් වේ.',
      'ta': 'புதிய நாளுக்கு மாற்றும்போது உங்கள் டோக்கன் எண் மாறும். பழைய இடம் மற்றொரு நோயாளிக்கு விடுவிக்கப்படும்.'
    },
    'rescheduledTo': {
      'en': 'Moved to {date}. Your new token is {token}.',
      'si': '{date} වෙත මාරු කරන ලදී. ඔබගේ නව අංකය {token}.',
      'ta': '{date} க்கு மாற்றப்பட்டது. உங்கள் புதிய டோக்கன் {token}.'
    },
    'noOtherDays': {
      'en': 'No other days are open for {clinic}. You can choose a different clinic below.',
      'si': '{clinic} සඳහා වෙනත් දින විවෘත නැත. පහතින් වෙනත් සායනයක් තෝරාගත හැක.',
      'ta': '{clinic} க்கு வேறு நாட்கள் இல்லை. கீழே வேறு சிகிச்சைப் பிரிவைத் தேர்ந்தெடுக்கலாம்.'
    },
    'cancelReason': {'en': 'Why are you cancelling?', 'si': 'අවලංගු කිරීමට හේතුව?', 'ta': 'ஏன் ரத்து செய்கிறீர்கள்?'},
    'cancelConsequence': {
      'en': 'Your place will be released so another patient can use it. This cannot be undone.',
      'si': 'ඔබගේ ස්ථානය වෙනත් රෝගියෙකුට ලබා දෙනු ඇත. මෙය ආපසු හැරවිය නොහැක.',
      'ta': 'உங்கள் இடம் மற்றொரு நோயாளிக்கு வழங்கப்படும். இதை மாற்ற முடியாது.'
    },
    'keepAppointment': {'en': 'Keep appointment', 'si': 'වේලාව තබා ගන්න', 'ta': 'சந்திப்பை வைத்திருக்கவும்'},
    'yesCancel': {'en': 'Yes, cancel it', 'si': 'ඔව්, අවලංගු කරන්න', 'ta': 'ஆம், ரத்து செய்யவும்'},
    'liveQueue': {'en': 'Live queue', 'si': 'සජීවී පෝලිම', 'ta': 'நேரலை வரிசை'},
    'nowServing': {'en': 'Now serving', 'si': 'දැන් සේවය ලබන්නේ', 'ta': 'இப்போது சேவை'},
    'patientsAhead': {'en': 'Patients ahead of you', 'si': 'ඔබට පෙර රෝගීන්', 'ta': 'உங்களுக்கு முன் நோயாளிகள்'},
    'estimatedWait': {'en': 'Estimated wait', 'si': 'ඇස්තමේන්තුගත කාලය', 'ta': 'மதிப்பிடப்பட்ட காத்திருப்பு'},
    'minutes': {'en': 'min', 'si': 'මිනි.', 'ta': 'நிமி.'},
    'nearTurn': {
      'en': 'Your turn is near — please return to the waiting area',
      'si': 'ඔබගේ වාරය ළඟයි — කරුණාකර පොරොත්තු ස්ථානයට පැමිණෙන්න',
      'ta': 'உங்கள் முறை நெருங்கியுள்ளது — காத்திருப்பு பகுதிக்குத் திரும்பவும்'
    },
    'yourTurn': {'en': "It's your turn", 'si': 'ඔබගේ වාරයයි', 'ta': 'உங்கள் முறை'},
    'goToRoom': {
      'en': 'Please go to the consultation room now',
      'si': 'කරුණාකර දැන් වෛද්‍ය කාමරයට යන්න',
      'ta': 'இப்போது ஆலோசனை அறைக்குச் செல்லவும்'
    },
    'imHere': {'en': "I'm at the hospital", 'si': 'මම රෝහලේ සිටිමි', 'ta': 'நான் மருத்துவமனையில் இருக்கிறேன்'},
    'arrivedNoted': {
      'en': 'Reception knows you have arrived',
      'si': 'ඔබ පැමිණි බව පිළිගැනීමේ නිලධාරීන් දනී',
      'ta': 'நீங்கள் வந்ததை வரவேற்பு அறிந்துள்ளது'
    },
    'queueNotStarted': {
      'en': 'The clinic has not started yet',
      'si': 'සායනය තවම ආරම්භ වී නැත',
      'ta': 'சிகிச்சை இன்னும் தொடங்கவில்லை'
    },
    'loading': {'en': 'Loading…', 'si': 'පූරණය වෙමින්…', 'ta': 'ஏற்றுகிறது…'},
    'retry': {'en': 'Try again', 'si': 'නැවත උත්සාහ කරන්න', 'ta': 'மீண்டும் முயற்சிக்கவும்'},
    'somethingWrong': {'en': 'Something went wrong', 'si': 'යමක් වැරදී ඇත', 'ta': 'ஏதோ தவறு நடந்தது'},
    'noSessions': {
      'en': 'No clinic days are open for booking at this hospital.',
      'si': 'මෙම රෝහලේ වෙන්කිරීම් සඳහා විවෘත සායන දින නොමැත.',
      'ta': 'இந்த மருத்துவமனையில் பதிவுக்கு திறந்த நாட்கள் இல்லை.'
    },
    'sessionFull': {
      'en': 'All places for this clinic day are taken. Please choose another day.',
      'si': 'මෙම දිනයේ සියලු ස්ථාන පිරී ඇත. වෙනත් දිනයක් තෝරන්න.',
      'ta': 'இந்த நாளுக்கான அனைத்து இடங்களும் நிரம்பிவிட்டன. வேறு நாளைத் தேர்ந்தெடுக்கவும்.'
    },
    'language': {'en': 'Language', 'si': 'භාෂාව', 'ta': 'மொழி'},
    'textSize': {'en': 'Text size', 'si': 'අකුරු ප්‍රමාණය', 'ta': 'எழுத்து அளவு'},
    'highContrast': {'en': 'High contrast mode', 'si': 'ඉහළ වෙනස්කම් ආකාරය', 'ta': 'உயர் மாறுபாடு பயன்முறை'},
    'preview': {
      'en': 'Preview: Your token is A-052',
      'si': 'පෙරදසුන: ඔබගේ අංකය A-052',
      'ta': 'முன்னோட்டம்: உங்கள் டோக்கன் A-052'
    },
    'saveSettings': {'en': 'Save settings', 'si': 'සැකසුම් සුරකින්න', 'ta': 'அமைப்புகளைச் சேமிக்கவும்'},
    'saved': {'en': 'Saved', 'si': 'සුරකින ලදී', 'ta': 'சேமிக்கப்பட்டது'},
    'signOut': {'en': 'Sign out', 'si': 'ඉවත් වන්න', 'ta': 'வெளியேறு'},
    'markAllRead': {
      'en': 'Mark all as read',
      'si': 'සියල්ල කියවූ ලෙස සලකුණු කරන්න',
      'ta': 'அனைத்தையும் படித்ததாகக் குறிக்கவும்'
    },
    'noNotifications': {
      'en': 'No notifications yet.',
      'si': 'තවම දැනුම්දීම් නොමැත.',
      'ta': 'இன்னும் அறிவிப்புகள் இல்லை.'
    },
    'status_waiting': {'en': 'Booked', 'si': 'වෙන් කර ඇත', 'ta': 'பதிவு செய்யப்பட்டது'},
    'status_serving': {'en': 'With doctor', 'si': 'වෛද්‍යවරයා සමඟ', 'ta': 'மருத்துவருடன்'},
    'status_completed': {'en': 'Completed', 'si': 'අවසන්', 'ta': 'முடிந்தது'},
    'status_cancelled': {'en': 'Cancelled', 'si': 'අවලංගුයි', 'ta': 'ரத்து செய்யப்பட்டது'},
    'status_noShow': {'en': 'Missed', 'si': 'මගහැරුණි', 'ta': 'தவறவிடப்பட்டது'},
    'reason_better': {'en': 'I feel better', 'si': 'මට දැන් සනීපයි', 'ta': 'நான் நலமாக உணர்கிறேன்'},
    'reason_clash': {'en': 'I have another commitment', 'si': 'මට වෙනත් කටයුත්තක් ඇත', 'ta': 'எனக்கு வேறு வேலை உள்ளது'},
    'reason_transport': {'en': 'Transport problem', 'si': 'ප්‍රවාහන ගැටලුවක්', 'ta': 'போக்குவரத்து பிரச்சனை'},
    'reason_wrong': {'en': 'Booked by mistake', 'si': 'වැරදීමකින් වෙන් කළා', 'ta': 'தவறுதலாக பதிவு செய்தேன்'},
    'reason_other': {'en': 'Other', 'si': 'වෙනත්', 'ta': 'மற்றவை'},
    'continue': {'en': 'Continue', 'si': 'ඉදිරියට', 'ta': 'தொடரவும்'},
    'back': {'en': 'Back', 'si': 'ආපසු', 'ta': 'பின்செல்'},
    // ---- Added with the home / records / profile redesign ----
    'navBookings': {'en': 'Bookings', 'si': 'වේලාවන්', 'ta': 'பதிவுகள்'},
    'records': {'en': 'My health', 'si': 'මගේ සෞඛ්‍යය', 'ta': 'என் உடல்நலம்'},
    'profile': {'en': 'Profile', 'si': 'පැතිකඩ', 'ta': 'சுயவிவரம்'},
    'editProfile': {'en': 'Edit profile', 'si': 'පැතිකඩ සංස්කරණය', 'ta': 'சுயவிவரத்தைத் திருத்து'},
    'changePassword': {'en': 'Change password', 'si': 'මුරපදය වෙනස් කරන්න', 'ta': 'கடவுச்சொல்லை மாற்று'},
    'help': {'en': 'Help & support', 'si': 'උදව් සහ සහාය', 'ta': 'உதவி மற்றும் ஆதரவு'},
    'goodMorning': {'en': 'Good morning', 'si': 'සුභ උදෑසනක්', 'ta': 'காலை வணக்கம்'},
    'goodAfternoon': {'en': 'Good afternoon', 'si': 'සුභ සවසක්', 'ta': 'மதிய வணக்கம்'},
    'goodEvening': {'en': 'Good evening', 'si': 'සුභ සන්ධ්‍යාවක්', 'ta': 'மாலை வணக்கம்'},
    'quickActions': {'en': 'Quick actions', 'si': 'ඉක්මන් ක්‍රියා', 'ta': 'விரைவு செயல்கள்'},
    'clinicsToday': {'en': 'Clinics running today', 'si': 'අද පවතින සායන', 'ta': 'இன்று நடைபெறும் சிகிச்சைகள்'},
    'visitHistory': {'en': 'Visit history', 'si': 'පැමිණීම් ඉතිහාසය', 'ta': 'வருகை வரலாறு'},
    'healthProfile': {'en': 'Health profile', 'si': 'සෞඛ්‍ය පැතිකඩ', 'ta': 'உடல்நல சுயவிவரம்'},
    'bloodGroup': {'en': 'Blood group', 'si': 'රුධිර වර්ගය', 'ta': 'இரத்த வகை'},
    'allergies': {'en': 'Allergies', 'si': 'අසාත්මිකතා', 'ta': 'ஒவ்வாமைகள்'},
    'all': {'en': 'All', 'si': 'සියල්ල', 'ta': 'அனைத்தும்'},
    'unread': {'en': 'Unread', 'si': 'නොකියවූ', 'ta': 'படிக்காதவை'},
    'search': {'en': 'Search', 'si': 'සොයන්න', 'ta': 'தேடு'},
    'reasonForVisit': {'en': 'Reason for visit (optional)', 'si': 'පැමිණීමේ හේතුව (අමතර)', 'ta': 'வருகைக்கான காரணம் (விருப்பம்)'},
    'estimatedSeen': {'en': 'Estimated time you will be seen', 'si': 'ඔබව බලන ඇස්තමේන්තුගත වේලාව', 'ta': 'உங்களைப் பார்க்கும் மதிப்பிடப்பட்ட நேரம்'},
    'placesLeftShort': {'en': 'left', 'si': 'ඉතිරි', 'ta': 'மீதம்'},
    'noClinicsToday': {'en': 'No clinics are running today.', 'si': 'අද සායන නොමැත.', 'ta': 'இன்று சிகிச்சைகள் இல்லை.'},
    // ---- Home ----
    'bookSub': {
      'en': 'Pick a hospital, clinic and day in 3 steps',
      'si': 'රෝහල, සායනය සහ දිනය පියවර 3කින් තෝරන්න',
      'ta': 'மூன்று படிகளில் மருத்துவமனை, சிகிச்சை, நாளைத் தேர்ந்தெடுக்கவும்'
    },
    'verifyEmailMsg': {
      'en': 'Please verify your e-mail so you can recover your account.',
      'si': 'ඔබගේ ගිණුම ප්‍රතිසාධනය කිරීමට විද්‍යුත් තැපෑල තහවුරු කරන්න.',
      'ta': 'உங்கள் கணக்கை மீட்டெடுக்க மின்னஞ்சலைச் சரிபார்க்கவும்.'
    },
    'iVerified': {'en': 'I verified', 'si': 'මම තහවුරු කළා', 'ta': 'சரிபார்த்துவிட்டேன்'},
    'resendEmail': {'en': 'Resend e-mail', 'si': 'නැවත යවන්න', 'ta': 'மீண்டும் அனுப்பு'},
    'emailVerifiedOk': {
      'en': 'E-mail verified. Thank you!',
      'si': 'විද්‍යුත් තැපෑල තහවුරු විය. ස්තූතියි!',
      'ta': 'மின்னஞ்சல் சரிபார்க்கப்பட்டது. நன்றி!'
    },
    'notVerifiedYet': {
      'en': 'Not verified yet. Open the link we e-mailed you.',
      'si': 'තවම තහවුරු කර නැත. අප එවූ සබැඳිය විවෘත කරන්න.',
      'ta': 'இன்னும் சரிபார்க்கப்படவில்லை. நாங்கள் அனுப்பிய இணைப்பைத் திறக்கவும்.'
    },
    'myBookings': {'en': 'My bookings', 'si': 'මගේ වෙන්කිරීම්', 'ta': 'என் பதிவுகள்'},
    'clinics': {'en': 'Clinics', 'si': 'සායන', 'ta': 'சிகிச்சைப் பிரிவுகள்'},
    'emergency1990': {'en': 'Emergency 1990', 'si': 'හදිසි 1990', 'ta': 'அவசரம் 1990'},
    'completed': {'en': 'Completed', 'si': 'අවසන්', 'ta': 'முடிந்தவை'},
    'cancelledMissed': {'en': 'Cancelled / missed', 'si': 'අවලංගු / මග හැරුණු', 'ta': 'ரத்து / தவறியவை'},
    'noTokenYet': {
      'en': 'Your token and live queue will appear here once you book.',
      'si': 'වෙන් කළ පසු ඔබගේ අංකය සහ සජීවී පෝලිම මෙහි පෙනේ.',
      'ta': 'பதிவு செய்தவுடன் உங்கள் டோக்கனும் நேரலை வரிசையும் இங்கே தெரியும்.'
    },
    'emergencyTitle': {'en': 'Emergency? Call 1990', 'si': 'හදිසි අවස්ථාවක්ද? 1990 අමතන්න', 'ta': 'அவசரமா? 1990 ஐ அழைக்கவும்'},
    'emergencyBody': {
      'en': 'Suwa Seriya free ambulance service (24 hours). Do not book an OPD slot for emergencies.',
      'si': 'සුව සැරිය නොමිලේ ගිලන්රථ සේවය (පැය 24). හදිසි අවස්ථාවලදී OPD වේලාවක් වෙන් නොකරන්න.',
      'ta': 'சுவ செரிய இலவச ஆம்புலன்ஸ் சேவை (24 மணி). அவசரத்திற்கு OPD நேரம் பதிவு செய்ய வேண்டாம்.'
    },
    'forPerson': {'en': 'For {name}', 'si': '{name} සඳහා', 'ta': '{name} க்காக'},
    'liveNotStarted': {
      'en': 'Clinic has not started · {n} ahead of you',
      'si': 'සායනය තවම ආරම්භ වී නැත · ඔබට පෙර {n}',
      'ta': 'சிகிச்சை இன்னும் தொடங்கவில்லை · உங்களுக்கு முன் {n}'
    },
    'liveNowServing': {
      'en': 'Now serving {token} · {n} ahead · ~{m} min',
      'si': 'දැන් {token} · ඔබට පෙර {n} · ~{m} මිනි.',
      'ta': 'இப்போது {token} · முன் {n} · ~{m} நிமி.'
    },
    'clinicHours': {'en': 'Clinic {start} – {end}', 'si': 'සායනය {start} – {end}', 'ta': 'சிகிச்சை {start} – {end}'},
    // ---- Clinics / booking ----
    'searchClinics': {
      'en': 'Search (clinic, doctor, hospital)',
      'si': 'සොයන්න (සායනය, වෛද්‍ය, රෝහල)',
      'ta': 'தேடு (சிகிச்சை, மருத்துவர், மருத்துவமனை)'
    },
    'availableOnly': {'en': 'Available only', 'si': 'ඉතිරි ස්ථාන ඇති ඒවා පමණි', 'ta': 'கிடைப்பவை மட்டும்'},
    'allHospitals': {'en': 'All hospitals', 'si': 'සියලු රෝහල්', 'ta': 'அனைத்து மருத்துவமனைகள்'},
    'allClinics': {'en': 'All clinics', 'si': 'සියලු සායන', 'ta': 'அனைத்து சிகிச்சைகள்'},
    'noMatchClinics': {
      'en': 'No clinics match your filters.',
      'si': 'ඔබේ පෙරහන්වලට ගැළපෙන සායන නැත.',
      'ta': 'வடிகட்டிகளுக்குப் பொருந்தும் சிகிச்சைகள் இல்லை.'
    },
    'liveNow': {
      'en': 'Live now: serving {token} · {n} waiting',
      'si': 'දැන් සජීවී: {token} · රැඳී සිටින {n}',
      'ta': 'இப்போது: {token} · காத்திருப்பவர் {n}'
    },
    'notStartedWaiting': {
      'en': 'Not started yet · {n} waiting',
      'si': 'තවම ආරම්භ වී නැත · රැඳී සිටින {n}',
      'ta': 'இன்னும் தொடங்கவில்லை · காத்திருப்பவர் {n}'
    },
    'bookedOf': {'en': '{a} of {b} booked', 'si': '{b} න් {a} වෙන් කර ඇත', 'ta': '{b} இல் {a} பதிவு'},
    'searchHospital': {
      'en': 'Search (name, town, district)',
      'si': 'සොයන්න (නම, නගරය, දිස්ත්‍රික්කය)',
      'ta': 'தேடு (பெயர், நகரம், மாவட்டம்)'
    },
    'noHospitalsMatch': {
      'en': 'No hospitals match your search.',
      'si': 'ඔබේ සෙවුමට ගැළපෙන රෝහල් නැත.',
      'ta': 'தேடலுக்குப் பொருந்தும் மருத்துவமனைகள் இல்லை.'
    },
    'noHospitalsYet': {
      'en': 'No hospitals are available for booking yet.\nPlease check again later or ask at the OPD counter.',
      'si': 'වෙන් කිරීමට රෝහල් තවම නැත.\nපසුව නැවත බලන්න, නැතහොත් OPD කවුළුවෙන් අසන්න.',
      'ta': 'பதிவு செய்ய மருத்துவமனைகள் இன்னும் இல்லை.\nபிறகு பார்க்கவும் அல்லது OPD கவுண்டரில் கேளுங்கள்.'
    },
    'clinicsTodayPill': {
      'en': '{n} clinics today · {m} places left',
      'si': 'අද සායන {n} · ස්ථාන {m} ඉතිරියි',
      'ta': 'இன்று {n} சிகிச்சைகள் · {m} இடங்கள்'
    },
    'noClinicsPill': {'en': 'No clinics today', 'si': 'අද සායන නැත', 'ta': 'இன்று சிகிச்சை இல்லை'},
    'noSessionsDay': {
      'en': 'No available sessions on this day.',
      'si': 'මෙම දිනයේ සැසි නැත.',
      'ta': 'இந்த நாளில் அமர்வுகள் இல்லை.'
    },
    'patientDetails': {'en': 'Patient details', 'si': 'රෝගියාගේ විස්තර', 'ta': 'நோயாளி விவரங்கள்'},
    'myself': {'en': 'Myself', 'si': 'මම', 'ta': 'நான்'},
    'someoneElse': {'en': 'Someone else', 'si': 'වෙනත් අයෙක්', 'ta': 'வேறொருவர்'},
    'patientName': {'en': 'Patient name *', 'si': 'රෝගියාගේ නම *', 'ta': 'நோயாளியின் பெயர் *'},
    'patientFullName': {'en': "Patient's full name *", 'si': 'රෝගියාගේ සම්පූර්ණ නම *', 'ta': 'நோயாளியின் முழுப் பெயர் *'},
    'mobileNumber': {'en': 'Mobile number *', 'si': 'ජංගම දුරකථන අංකය *', 'ta': 'கைபேசி எண் *'},
    'contactNumber': {'en': 'Contact number *', 'si': 'සම්බන්ධතා අංකය *', 'ta': 'தொடர்பு எண் *'},
    'nicNumber': {'en': 'NIC number *', 'si': 'ජාතික හැඳුනුම්පත් අංකය *', 'ta': 'அடையாள அட்டை எண் *'},
    'nicOptionalChild': {
      'en': 'NIC number (optional for children)',
      'si': 'ජා.හැ.අංකය (ළමුන්ට අවශ්‍ය නැත)',
      'ta': 'அடையாள அட்டை எண் (குழந்தைகளுக்கு தேவையில்லை)'
    },
    'ageYears': {'en': 'Age (years) *', 'si': 'වයස (අවුරුදු) *', 'ta': 'வயது (ஆண்டுகள்) *'},
    'genderReq': {'en': 'Gender *', 'si': 'ස්ත්‍රී/පුරුෂ භාවය *', 'ta': 'பாலினம் *'},
    'relationship': {'en': 'Relationship to you *', 'si': 'ඔබ සමඟ ඇති සම්බන්ධය *', 'ta': 'உங்களுடன் உறவு *'},
    'room': {'en': 'Room', 'si': 'කාමරය', 'ta': 'அறை'},
    'expectedShort': {'en': 'Expected', 'si': 'අපේක්ෂිත', 'ta': 'எதிர்பார்ப்பு'},
    'bringNic': {
      'en': 'Please bring your NIC and arrive 15 minutes early.',
      'si': 'ජා.හැ.පත ගෙන විනාඩි 15කට කලින් පැමිණෙන්න.',
      'ta': 'அடையாள அட்டையைக் கொண்டுவந்து 15 நிமிடம் முன்னதாக வரவும்.'
    },
    'hoursBeforeClinic': {'en': '{n} hours before the clinic', 'si': 'සායනයට පැය {n}කට පෙර', 'ta': 'சிகிச்சைக்கு {n} மணி நேரம் முன்'},
    'reasonHint': {
      'en': 'e.g. fever for 3 days, diabetes review',
      'si': 'උදා: දින 3ක උණ, දියවැඩියා පරීක්ෂාව',
      'ta': 'எ.கா. 3 நாள் காய்ச்சல், நீரிழிவு பரிசோதனை'
    },
    'selectGender': {'en': "Select the patient's gender", 'si': 'රෝගියාගේ ස්ත්‍රී/පුරුෂ භාවය තෝරන්න', 'ta': 'நோயாளியின் பாலினத்தைத் தேர்ந்தெடுக்கவும்'},
    'male': {'en': 'Male', 'si': 'පුරුෂ', 'ta': 'ஆண்'},
    'female': {'en': 'Female', 'si': 'ස්ත්‍රී', 'ta': 'பெண்'},
    'other': {'en': 'Other', 'si': 'වෙනත්', 'ta': 'மற்றது'},
    // ---- Appointments ----
    'searchAppts': {
      'en': 'Search (clinic, hospital, doctor, token)',
      'si': 'සොයන්න (සායනය, රෝහල, වෛද්‍ය, අංකය)',
      'ta': 'தேடு (சிகிச்சை, மருத்துவமனை, மருத்துவர், டோக்கன்)'
    },
    'next7': {'en': 'Next 7 days', 'si': 'ඉදිරි දින 7', 'ta': 'அடுத்த 7 நாட்கள்'},
    'noApptMatch': {'en': 'No appointments match.', 'si': 'ගැළපෙන වේලාවන් නැත.', 'ta': 'பொருந்தும் சந்திப்புகள் இல்லை.'},
    'reasonLabel': {'en': 'Reason', 'si': 'හේතුව', 'ta': 'காரணம்'},
    // ---- Live queue ----
    'expectedCall': {
      'en': 'Expected to be called around',
      'si': 'ඔබව කැඳවීමට අපේක්ෂිත වේලාව',
      'ta': 'உங்களை அழைக்க எதிர்பார்க்கப்படும் நேரம்'
    },
    'youAreNext': {
      'en': 'You are next! Please wait outside the consultation room.',
      'si': 'ඔබ ඊළඟයි! කරුණාකර වෛද්‍ය කාමරයෙන් පිටත රැඳී සිටින්න.',
      'ta': 'அடுத்தது நீங்கள்! ஆலோசனை அறைக்கு வெளியே காத்திருக்கவும்.'
    },
    'patientLabel': {'en': 'Patient', 'si': 'රෝගියා', 'ta': 'நோயாளி'},
    'referenceLabel': {'en': 'Reference', 'si': 'යොමු අංකය', 'ta': 'குறிப்பு'},
    'tl_booked': {'en': 'Booked', 'si': 'වෙන් කළා', 'ta': 'பதிவு'},
    'tl_checkedIn': {'en': 'Checked in', 'si': 'පැමිණියා', 'ta': 'வந்தார்'},
    'tl_near': {'en': 'Turn near', 'si': 'වාරය ළඟයි', 'ta': 'முறை நெருங்கியது'},
    'tl_doctor': {'en': 'With doctor', 'si': 'වෛද්‍යවරයා සමඟ', 'ta': 'மருத்துவருடன்'},
    'tl_done': {'en': 'Done', 'si': 'අවසන්', 'ta': 'முடிந்தது'},
    'qrTitle': {'en': 'Check-in QR code', 'si': 'පැමිණීම තහවුරු කිරීමේ QR කේතය', 'ta': 'வருகை QR குறியீடு'},
    'qrSub': {'en': 'Show this at the OPD counter', 'si': 'මෙය OPD කවුළුවේදී පෙන්වන්න', 'ta': 'இதை OPD கவுண்டரில் காட்டவும்'},
    'copyRef': {'en': 'Copy reference', 'si': 'යොමු අංකය පිටපත් කරන්න', 'ta': 'குறிப்பை நகலெடு'},
    'refCopied': {'en': 'Reference copied', 'si': 'යොමු අංකය පිටපත් විය', 'ta': 'குறிப்பு நகலெடுக்கப்பட்டது'},
    'rateTitle': {'en': 'How was your visit?', 'si': 'ඔබගේ පැමිණීම කෙසේද?', 'ta': 'உங்கள் வருகை எப்படி இருந்தது?'},
    'rateHint': {'en': 'Tell us more (optional)', 'si': 'තව කියන්න (අමතර)', 'ta': 'மேலும் சொல்லுங்கள் (விருப்பம்)'},
    'submitFeedback': {'en': 'Submit feedback', 'si': 'ප්‍රතිපෝෂණය යවන්න', 'ta': 'கருத்தை அனுப்பு'},
    'thanksFeedback': {
      'en': 'Thanks! Your feedback helps the hospital improve.',
      'si': 'ස්තූතියි! ඔබේ ප්‍රතිපෝෂණය රෝහලට වැඩිදියුණු වීමට උපකාරී වේ.',
      'ta': 'நன்றி! உங்கள் கருத்து மருத்துவமனை மேம்பட உதவும்.'
    },
    'tapStars': {'en': 'Tap the stars to rate your visit', 'si': 'ඇගයීමට තරු තට්ටු කරන්න', 'ta': 'மதிப்பிட நட்சத்திரங்களைத் தொடவும்'},
    'queuePausedMsg': {
      'en': 'The queue is paused: {reason}. Please stay nearby.',
      'si': 'පෝලිම නවතා ඇත: {reason}. කරුණාකර ළඟම රැඳී සිටින්න.',
      'ta': 'வரிசை நிறுத்தப்பட்டுள்ளது: {reason}. அருகிலேயே இருக்கவும்.'
    },
    'clinicLateMsg': {
      'en': 'The clinic is running about {n} minutes late. Your expected time already includes this.',
      'si': 'සායනය මිනිත්තු {n}ක් පමා වී ඇත. ඔබගේ අපේක්ෂිත වේලාවට මෙය ඇතුළත්ය.',
      'ta': 'சிகிச்சை சுமார் {n} நிமிடம் தாமதம். உங்கள் எதிர்பார்ப்பு நேரத்தில் இது சேர்க்கப்பட்டுள்ளது.'
    },
    'receptionMsg': {'en': 'Message from reception: {msg}', 'si': 'පිළිගැනීමෙන් පණිවිඩය: {msg}', 'ta': 'வரவேற்பிலிருந்து செய்தி: {msg}'},
    // ---- My health ----
    'healthLoading': {
      'en': 'Your health record is being set up. Please check again shortly.',
      'si': 'ඔබගේ සෞඛ්‍ය වාර්තාව සකසමින් පවතී. මදක් පසුව බලන්න.',
      'ta': 'உங்கள் உடல்நலப் பதிவு அமைக்கப்படுகிறது. சிறிது நேரம் கழித்துப் பார்க்கவும்.'
    },
    'edit': {'en': 'Edit', 'si': 'සංස්කරණය', 'ta': 'திருத்து'},
    'ageLabel': {'en': 'Age', 'si': 'වයස', 'ta': 'வயது'},
    'genderLabel': {'en': 'Gender', 'si': 'ස්ත්‍රී/පුරුෂ', 'ta': 'பாலினம்'},
    'noneRecorded': {'en': 'None recorded', 'si': 'වාර්තා නැත', 'ta': 'பதிவு இல்லை'},
    'emergencyContact': {'en': 'Emergency contact', 'si': 'හදිසි සම්බන්ධතා', 'ta': 'அவசரத் தொடர்பு'},
    'noVisits': {
      'en': 'No visits yet. After your first clinic visit it will appear here.',
      'si': 'තවම පැමිණීම් නැත. පළමු සායන පැමිණීමෙන් පසු මෙහි පෙනේ.',
      'ta': 'இன்னும் வருகைகள் இல்லை. முதல் வருகைக்குப் பிறகு இங்கே தெரியும்.'
    },
    'viewAllVisits': {
      'en': 'View all visits',
      'si': 'සියලු පැමිණීම් බලන්න',
      'ta': 'அனைத்து வருகைகளையும் பார்க்க'
    },
    'searchVisits': {
      'en': 'Search by clinic, doctor or diagnosis',
      'si': 'සායනය, වෛද්‍යවරයා හෝ රෝග විනිශ්චය අනුව සොයන්න',
      'ta': 'பிரிவு, மருத்துவர் அல்லது நோய் கண்டறிதல் மூலம் தேடுக'
    },
    'noMatchingVisits': {
      'en': 'No visits match your search.',
      'si': 'ඔබගේ සෙවුමට ගැළපෙන පැමිණීම් නැත.',
      'ta': 'உங்கள் தேடலுக்கு பொருந்தும் வருகைகள் இல்லை.'
    },
    'totalVisits': {'en': 'Total visits', 'si': 'මුළු පැමිණීම්', 'ta': 'மொத்த வருகைகள்'},
    'lastVisit': {'en': 'Last visit', 'si': 'අවසන් පැමිණීම', 'ta': 'கடைசி வருகை'},
    'diagnosis': {'en': 'Diagnosis', 'si': 'රෝග විනිශ්චය', 'ta': 'நோய் கண்டறிதல்'},
    'notRecorded': {'en': 'Not recorded', 'si': 'වාර්තා කර නැත', 'ta': 'பதிவு செய்யப்படவில்லை'},
    'notes': {'en': 'Notes', 'si': 'සටහන්', 'ta': 'குறிப்புகள்'},
    // ---- Notifications ----
    'f_unread': {'en': 'Unread', 'si': 'නොකියවූ', 'ta': 'படிக்காதவை'},
    'f_queue': {'en': 'Queue', 'si': 'පෝලිම', 'ta': 'வரிசை'},
    'f_bookings': {'en': 'Bookings', 'si': 'වෙන්කිරීම්', 'ta': 'பதிவுகள்'},
    'f_changes': {'en': 'Clinic changes', 'si': 'සායන වෙනස්කම්', 'ta': 'சிகிச்சை மாற்றங்கள்'},
    'allCaughtUp': {'en': 'You are all caught up', 'si': 'සියල්ල කියවා ඇත', 'ta': 'அனைத்தும் படிக்கப்பட்டன'},
    'nUnread': {'en': '{n} unread', 'si': 'නොකියවූ {n}', 'ta': '{n} படிக்காதவை'},
    'nothingFilter': {'en': 'Nothing in this filter.', 'si': 'මෙම පෙරහනේ කිසිවක් නැත.', 'ta': 'இந்த வடிகட்டியில் ஒன்றும் இல்லை.'},
    'yesterday': {'en': 'Yesterday', 'si': 'ඊයේ', 'ta': 'நேற்று'},
    'clearRead': {'en': 'Clear read notifications', 'si': 'කියවූ දැනුම්දීම් මකන්න', 'ta': 'படித்தவற்றை நீக்கு'},
    // ---- Settings / profile ----
    'accountSection': {'en': 'Account', 'si': 'ගිණුම', 'ta': 'கணக்கு'},
    'contact': {'en': 'Contact', 'si': 'සම්බන්ධතා', 'ta': 'தொடர்பு'},
    'mobile': {'en': 'Mobile', 'si': 'ජංගම', 'ta': 'கைபேசி'},
    'email': {'en': 'Email', 'si': 'විද්‍යුත් තැපෑල', 'ta': 'மின்னஞ்சல்'},
    'address': {'en': 'Address', 'si': 'ලිපිනය', 'ta': 'முகவரி'},
    'dob': {'en': 'Date of birth', 'si': 'උපන් දිනය', 'ta': 'பிறந்த தேதி'},
    'saveChanges': {'en': 'Save changes', 'si': 'වෙනස්කම් සුරකින්න', 'ta': 'மாற்றங்களைச் சேமி'},
    'cancelBtn': {'en': 'Cancel', 'si': 'අවලංගු', 'ta': 'ரத்து'},
    'currentPassword': {'en': 'Current password', 'si': 'වත්මන් මුරපදය', 'ta': 'தற்போதைய கடவுச்சொல்'},
    'newPassword': {'en': 'New password', 'si': 'නව මුරපදය', 'ta': 'புதிய கடவுச்சொல்'},
    'confirmNewPassword': {'en': 'Confirm new password', 'si': 'නව මුරපදය තහවුරු කරන්න', 'ta': 'புதிய கடவுச்சொல்லை உறுதிப்படுத்து'},
    'verifyEmailBtn': {'en': 'Verify e-mail', 'si': 'විද්‍යුත් තැපෑල තහවුරු කරන්න', 'ta': 'மின்னஞ்சலைச் சரிபார்'},
    'signOutQ': {'en': 'Sign out?', 'si': 'ඉවත් වන්නද?', 'ta': 'வெளியேறவா?'},
    'signOutMsg': {'en': 'You will need to sign in again.', 'si': 'ඔබට නැවත පිවිසිය යුතුය.', 'ta': 'நீங்கள் மீண்டும் உள்நுழைய வேண்டும்.'},
    'faq': {'en': 'Frequently asked questions', 'si': 'නිතර අසන ප්‍රශ්න', 'ta': 'அடிக்கடி கேட்கப்படும் கேள்விகள்'},
    'healthDetails': {'en': 'Health details', 'si': 'සෞඛ්‍ය විස්තර', 'ta': 'உடல்நல விவரங்கள்'},
    // ---- Health tips (home) ----
    'tip0': {
      'en': 'Drink plenty of clean water, especially in hot weather.',
      'si': 'උණුසුම් කාලගුණයේදී විශේෂයෙන් පිරිසිදු වතුර බොහෝ සෙයින් පානය කරන්න.',
      'ta': 'வெப்பமான காலநிலையில் தூய தண்ணீரை நிறைய குடிக்கவும்.'
    },
    'tip1': {
      'en': 'Wash your hands with soap before meals and after using the toilet.',
      'si': 'ආහාර ගැනීමට පෙර සහ වැසිකිළි භාවිතයෙන් පසු සබන් යොදා අත් සෝදන්න.',
      'ta': 'உணவுக்கு முன்பும் கழிவறைக்குப் பின்பும் சோப்பால் கைகளைக் கழுவவும்.'
    },
    'tip2': {
      'en': 'Take your medicines exactly as prescribed, even when you feel better.',
      'si': 'සනීප වුවත් බෙහෙත් නියම කළ පරිදි ගන්න.',
      'ta': 'நலமாக உணர்ந்தாலும் மருந்துகளை பரிந்துரைத்தபடியே எடுத்துக்கொள்ளவும்.'
    },
    'tip3': {
      'en': 'A 30-minute walk each day lowers the risk of diabetes and heart disease.',
      'si': 'දිනපතා විනාඩි 30ක ඇවිදීම දියවැඩියාව සහ හෘද රෝග අවදානම අඩු කරයි.',
      'ta': 'தினமும் 30 நிமிட நடை நீரிழிவு, இதய நோய் ஆபத்தைக் குறைக்கும்.'
    },
    'tip4': {
      'en': 'Cover your mouth and nose when coughing or sneezing.',
      'si': 'කැස්ස හෝ කිවිසුම් යන විට මුඛය සහ නාසය වසා ගන්න.',
      'ta': 'இருமும்போது அல்லது தும்மும்போது வாய், மூக்கை மூடிக்கொள்ளவும்.'
    },
    'tip5': {
      'en': 'Keep your clinic book and NIC together so they are easy to find.',
      'si': 'සායන පොත සහ ජා.හැ.පත එකට තබා ගන්න.',
      'ta': 'சிகிச்சைப் புத்தகத்தையும் அடையாள அட்டையையும் ஒன்றாக வைக்கவும்.'
    },
    'tip6': {
      'en': 'Sleep 7–8 hours a night. Rest helps your body recover.',
      'si': 'රාත්‍රියකට පැය 7–8ක් නිදාගන්න. විවේකය සුවය ලබා දේ.',
      'ta': 'இரவில் 7–8 மணி நேரம் தூங்கவும். ஓய்வு உடல் மீள உதவும்.'
    },
    // ---- Login / register ----
    'welcomeBack': {'en': 'Welcome back', 'si': 'නැවත සාදරයෙන් පිළිගනිමු', 'ta': 'மீண்டும் வரவேற்கிறோம்'},
    'loginSub': {
      'en': 'Sign in to book appointments and follow your queue.',
      'si': 'වේලාවන් වෙන් කිරීමට සහ පෝලිම බැලීමට පිවිසෙන්න.',
      'ta': 'சந்திப்புகளைப் பதிவு செய்யவும் வரிசையைப் பின்தொடரவும் உள்நுழையவும்.'
    },
    'password': {'en': 'Password', 'si': 'මුරපදය', 'ta': 'கடவுச்சொல்'},
    'signIn': {'en': 'Sign in', 'si': 'පිවිසෙන්න', 'ta': 'உள்நுழை'},
    'createAccount': {'en': 'Create an account', 'si': 'ගිණුමක් සාදන්න', 'ta': 'கணக்கை உருவாக்கு'},
    'forgotPassword': {'en': 'Forgot password?', 'si': 'මුරපදය අමතකද?', 'ta': 'கடவுச்சொல் மறந்துவிட்டதா?'},
    'helpEmergency': {'en': 'Help & emergency numbers', 'si': 'උදව් සහ හදිසි අංක', 'ta': 'உதவி மற்றும் அவசர எண்கள்'},
    'fullName': {'en': 'Full name', 'si': 'සම්පූර්ණ නම', 'ta': 'முழுப் பெயர்'},
    'iAm': {'en': 'I am a…', 'si': 'මම…', 'ta': 'நான் ஒரு…'},
    'patientRole': {'en': 'Patient', 'si': 'රෝගියෙක්', 'ta': 'நோயாளி'},
    'confirmPassword': {'en': 'Confirm password', 'si': 'මුරපදය තහවුරු කරන්න', 'ta': 'கடவுச்சொல்லை உறுதிப்படுத்து'},
  };
}
