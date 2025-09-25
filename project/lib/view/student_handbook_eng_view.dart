import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:project/widgets/custom_appbar.dart';
import 'student_handbook_tr_view.dart';
import 'package:url_launcher/url_launcher.dart';

class StudentHandbookEngView extends StatelessWidget {
	const StudentHandbookEngView({super.key});

	@override
	Widget build(BuildContext context) {
		return AppScaffold(
			title: 'Student Handbook',
			actions: [
				Padding(
					padding: const EdgeInsets.only(right: 4),
					child: _LanguageMenu(
						current: 'EN',
						onSelect: (code) {
							if (code == 'TR') {
								Navigator.of(context).pushReplacement(
									MaterialPageRoute(builder: (_) => const StudentHandbookTrView()),
								);
							}
						},
					),
				),
			],
			body: ListView(
				padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
				children: [
					_section(
						context,
						icon: Icons.emoji_people_rounded,
						title: 'Welcome',
						children: [
						  _Bullet(
								"Welcome! You are now one of us, and we are happy to have you here. "
								"This guide is prepared to make your first days easier and to help you get familiar with the campus. "
								"Before we start, you might want to take a quick look at this campus tour video for a visual impression:",
							),
							_linkTile(
								context,
								label: '2‑min Campus Tour',
								url: 'https://www.youtube.com/embed/zmGS52SPeJ0?rel=0',
							),
						],
					),
					_section(
						context,
						icon: Icons.airport_shuttle_rounded,
						title: 'Getting Here (Ercan → Campus)',
						children: [
							const _Bullet(
								"When you land at Ercan Airport, don’t stress about how to get to campus. "
								"Right after you exit the airport, you will see the KIBHAS office on your left. "
								"KIBHAS is the bus company that connects different parts of the island, and they have a direct route to our university. "
								"Just buy a ticket, tell them you’re heading to ODTÜ, and take your seat. "
								"The bus brings you straight to campus—easy.",
							),
							_linkTile(
								context,
								label: 'Transportation details (Campus Life)',
								url: 'https://ncc.metu.edu.tr/tr/kampusta-yasam',
							),
						],
					),
					_section(
						context,
						icon: Icons.home_rounded,
						title: 'Dormitories',
						children: [
							const _Bullet("Dorm 2 is the first one you’ll notice right in front of the bus stop."
              "Each unit has three rooms, along with a common kitchen and bathroom."
              "If you’ve been placed here, simply head inside and the dorm staff will take you to your room."
              "A café named Noshi is located at dorm 2, you can find it across the entrance of Dorm 3 with various dessert and drink options. "
              ),
							const _Bullet("Dorm 3 is located to the left of Dorm 2."
              "The rooms here are designed for either two or four students, with a shared study area in the center."
              "In the two-person rooms, each student has their own section, while in the four-person rooms, there are two beds in each section."
              "The kitchen and bathrooms are shared per floor."
              ),
							_Bullet("Dorm 1 is the white building across from Dorm 3."
              "The setup is similar to Dorm 3, but with one major difference:"
              "the rooms here have their own bathrooms, and all beds are in the same area rather than being divided into sections."
              ),
							_Bullet("EBI is the newest dorm on campus, located behind Dorms 2 and 3."
              "To reach it, just walk between the two buildings until you see the new structure at the bottom."
              "Like the others, the dorm staff will help you once you arrive."
              ),
							_Bullet("Dorm 4 is a bit further away, near the top gate of the campus."
              "It takes around 15 minutes to walk from there to the academic buildings, so it’s slightly more distant but still very manageable."
			  ),
							const _Bullet("Dorm staff help with check‑in any time—just ask security."),
						],
					),
					_section(
						context,
						icon: Icons.shopping_basket_rounded,
						title: 'Exploring the Campus',
						children: [
							const _Bullet("Back at the bus stop, you’ll notice stairs leading up to the Macro supermarket."
              "Macro is a well-known supermarket chain on the island, and luckily we have one right on campus."
              "It’s the perfect place to shop for your everyday needs."
              "If you’d like more options later, there’s also Kaş Market in Kalkanlı, which we’ll mention again in the Kalkanlı section of this guide."
              ),
							const _Bullet("Next to Macro, you’ll see İş Bankası."
              "If you don’t already have a bank account, we recommend opening one here because not every shop accepts international cards."
              "In front of the bank, you’ll also find two İş Bank ATMs and a Ziraat Bank ATM near the bus stop."
              "These are the only ATMs available on campus."
              ),
							_Bullet("If you keep walking, you’ll find a small street where the campus barber and hairdresser are located."
              "At the end of that street, there’s Deniz Plaza, the arts and crafts shop."
              "This is where you’ll find stationery, notebooks, pens, and sometimes even your course books."
              ),
							_Bullet("Right next to Deniz Plaza, you’ll find the tailor and the KKTCELL service point."
              "You’ll eventually need to register your phone in order to use it on the island, but don’t worry — the registration team comes directly to campus on certain dates."
              "Just keep an eye on your student email, and you’ll know when it’s happening."
              ),
						],
					),
					_section(
						context,
						icon: Icons.group_rounded,
						title: 'Student Associations',
						children: [
              const _Bullet(
              "We have numerous associations that connects our students such as ISA (International Students Association),"
              "PSS (Problem Solving Society), Women In Engineering, Animal Welfare Society, ACM (Association for Computing Machinery) and many more. "
              "You can find some of the association rooms above Deniz Plaza and Macro market. ",
              ),
						],
					),
					_section(
						context,
						icon: Icons.restaurant_menu_rounded,
						title: 'Food & cafés',
						children: [
              const _Bullet(
              "Following the road past the bank, you’ll reach the Main Cafeteria."
              "The first floor has been turned into a gaming lounge, and the upper floor is a rooftop restaurant."
              "Here you can enjoy daily homemade meals, and from time to time even dishes from different cuisines."
              "Just next to it is the Patisserie (patisserie and main cafeteria is connected at the top floor, having the rooftop restaurant), where you can grab quick bites such as döner, burgers, or pastries."
              "If you head upstairs, you’ll also find a cozy café called Teras Café where you can sit with friends, sip coffee, and enjoy desserts."
              "You should definitely visit there and see our campus and mountains view!"
              )
						],
					),
					_section(
						context,
						icon: Icons.shield_moon_rounded,
						title: "Security Guard's Office",
						children: [
							const _Bullet("If you lose something or need to check with campus security, their office is located between the entrances of the Main Cafeteria and the Patisserie."
              "It’s always a good idea to check there if you’ve misplaced an item."
              ),
						],
					),
					_section(
						context,
						icon: Icons.wifi_rounded,
						title: 'Internet & IT',
						children: [
							const _Bullet("Our university provides wireless internet throughout the campus, but to use it you need to register your devices at the Information Technologies (IT) building."
              "The IT building is just behind the Main Cafeteria."
              "From the cafeteria entrance, take the road to the left and you’ll soon see the building on your left, right after the statue."
              "Inside, you’ll also find computer rooms for study, and if you’re a CNG or SNG student, some of your lab classes will take place here."
              "You can register up to two devices, so choose carefully!"
              ),
              _linkTile(
								context,
								label: 'For details, check this document: ',
								url: 'https://ncc.metu.edu.tr/sites/default/files/RegistrationofElectronicDevices2022-23.pdf',             
							),
              _linkTile(  
                context,
                label: 'IT website',
                url: 'https://ncc.metu.edu.tr/tr/btm',
                ),
						],
						footerLinks: [
							_FooterLink('IT website', 'https://ncc.metu.edu.tr/tr/btm'),
						],
					),
					_section(
						context,
						icon: Icons.local_library_rounded,
						title: 'Library',
						children: [
							const _Bullet("Next to the IT building is the Library, one of the most important places on campus."
              "It has three floors with common study areas and group rooms that you can book online."
              "There’s also the option to use a copycard here, which we’ll explain later."
              "For a closer look, you can watch the library tour video:"
              ),
              _linkTile(
								context,
								label: 'Library Tour (YouTube)',
								url: 'https://www.youtube.com/embed/6th5JCPMfq0?rel=0',
							),
						],					
					),
					_section(
						context,
						icon: Icons.account_balance_rounded,
						title: 'Rector’s Building and Student Affairs',
						children: [
							const _Bullet("Right next to the Library is the Rector’s Building, which also houses Student Affairs."
              "If you ever need a transcript, a new student card, or help with course-related problems, this is the place to go."
              "Basically, if you’re not sure where to solve a problem, Student Affairs is your safest bet."
              ),
						],
					),
					_section(
						context,
						icon: Icons.school_rounded,
						title: 'Academic Buildings and Prep School',
						children: [
							const _Bullet("Back near the Main Cafeteria, you’ll notice stairs leading down to the Prep School building."
              "If you are studying in the English prep program, this is where most of your classes will take place."
              "If you are starting directly in your department, you will spend most of your time in the three main academic buildings: T, R, and S."
              ),
							const _Bullet("The T (Teaching) Building is where you’ll find lecture halls and a small café."
              "The R (Research) Building has several laboratories."
              "The S Building has a nice terrace on the upper floor."
              "All three are connected by bridges, so you can move between them without going outside."
              ),
							const _Bullet("Classrooms are coded by building, floor, and room number."
              "For example, TZ-111 means T building, ground floor, room 111; R-103 means R building, first floor, room 103; and S-201 means S building, second floor, room 201."),
						],
						footerLinks: [
							_FooterLink('More about the School of Foreign Languages', 'https://ncc.metu.edu.tr/sfl/general-info'),
						],
					),
					_section(
						context,
						icon: Icons.health_and_safety_rounded,
						title: 'Medico and Sports Center',
						children: [
							const _Bullet("Following the road from the bus stop, you’ll see Medico, the campus health center, located across from the football field."
              "It provides basic medical care and is also where you go if you need health reports added to the system."
              "Continuing down the same road, you’ll reach the Sports Center, which includes tennis courts, a gym, an indoor basketball court, and table tennis."
              "Nearby you’ll also find the climbing wall, swimming pool, outdoor basketball and volleyball courts, and a running track."
              ),
						],
						footerLinks: [
							_FooterLink('More about Medico', 'https://www.youtube.com/embed/ek3Jh-1xt78?rel=0'),
							_FooterLink('More about the Sports', 'https://ncc.metu.edu.tr/campus-life/sports-mission'),
						],
					),
          _section(
						context,
						icon: Icons.card_membership_rounded,
						title: 'Student Card and Copycard',
						children: [
						_BulletInline([
							const TextSpan(text: "There are two cards you’ll need on campus: the student card and the copycard. "),
							const TextSpan(text: "Your student card is essential for using the buses and can be loaded with credits online at "),
							TextSpan(
								text: 'cyppass.com',
								style: TextStyle(
									color: Colors.lightBlue,
									decoration: TextDecoration.underline,
									fontWeight: FontWeight.w600,
								),
								recognizer: TapGestureRecognizer()..onTap = () => _openUrl(context, 'https://www.cyppass.com/tr'),
							),
							const TextSpan(text: " or at the station near the bus stop. "),
							const TextSpan(text: "The copycard is used for printing in the dorms and library. "),
							const TextSpan(text: "You can get one directly from the Library and load balance there."),
						]),
						],
					),
					_section(
						context,
						icon: Icons.directions_bus_rounded,
						title: 'Bus System',
						children: [
							const _Bullet("The local bus system connects the campus with Kalkanlı and Güzelyurt."
              "Buses leave campus every hour, first stopping in Kalkanlı and ending at the Güzelyurt terminal."
              "They then return on the same route back to campus."
              ),
							_linkTile(
								context,
								label: 'Top up at cyppass.com',
								url: 'https://www.cyppass.com/tr',
							),
							const _Bullet("Copycard: for printing in dorms/Library; buy and load at the Library."),
						],
					),
					_section(
						context,
						icon: Icons.map_rounded,
						title: 'Campus Gates',
						children: [
							const _Bullet("The campus has two main gates."
              "The top gate leads directly to Kalkanlı village, where you’ll find restaurants, the Lombard café, and Kaş Market."
              "To reach Kaş Market, walk straight from the gate to Lombard, turn left at the end of the road, and you’ll see the Kaş sign on your right."
              "The bottom gate leads to another café called VOY."
              ),
						],
					),
					_section(
						context,
						icon: Icons.event_rounded,
						title: 'Cafes on Campus',
						children: [
							const _Bullet("One of the most popular spots is Segafredo Tchibo Café, located just under the Atatürk statue near the bus stop."
              "It’s a great place to grab coffee, desserts, and spend time with friends between classes or in the evenings."
              ),
						],
					),
          _section(
            context,
            icon: Icons.business_center_rounded,
            title: 'CCC, Engineering Labs, and Kaltev',
            children: [
              const _Bullet("In front of the METU NCC statue, next to the Prep School, is the CCC Building, the main venue for campus events."
              "Keep an eye on your email or HocamConnect app for announcements under 'This Week On Campus' to know what’s happening there."
              "Behind CCC are the engineering laboratory buildings, where some departmental labs take place."
              "Further behind them is Kaltev (Kalkanlı Technology Valley), home to startups, research projects, and innovation spaces."
              ),
              _Bullet("A cozy and futuristic restaurant/café is located at the bottom floor of Kaltev, called Root."
              "Root looks like a stylish arcade room with its unique decoration."
              "The arcade machines are playable, and you’ll also find plenty of board games to enjoy with friends."
              ),
            ],
            footerLinks: [
              _FooterLink('More about Kaltev', 'https://odtukaltev.com.tr/'),
            ],
          ),
					_section(
						context,
						icon: Icons.timeline_rounded,
						title: 'Course Registration and ODTUClass',
						children: [
							_linkTile(
								context,
								label: 'How to add courses (YouTube)',
								url: 'https://www.youtube.com/embed/bi12NWyXwSg?rel=0',
							),
							_linkTile(
								context,
								label: 'Plan your schedule (CET)',
								url: 'https://cet.ncc.metu.edu.tr/',
							),
							_linkTile(
								context,
								label: 'ODTUClass basics (YouTube)',
								url: 'https://www.youtube.com/embed/pn5FaG8KNVU?rel=0',
							),
						],
					),
					const SizedBox(height: 8),
					const Text(
						'Tip: Save links you use often to your browser or homescreen.',
						style: TextStyle(color: Colors.black54),
					),
				],
			),
		);
	}
}

class _BulletInline extends StatelessWidget {
	const _BulletInline(this.spans);
	final List<TextSpan> spans;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.only(bottom: 8.0),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Padding(
						padding: EdgeInsets.only(top: 6.0, right: 8.0),
						child: Icon(Icons.circle, size: 8, color: Colors.grey),
					),
					Expanded(
						child: RichText(
							text: TextSpan(
								style: DefaultTextStyle.of(context).style.merge(const TextStyle(height: 1.35, fontSize: 14)),
								children: spans,
							),
						),
					),
				],
			),
		);
	}
}

// ----- UI helpers -----

Widget _section(
	BuildContext context, {
	required IconData icon,
	required String title,
	required List<Widget> children,
	List<_FooterLink> footerLinks = const [],
}) {
	final linkStyle = TextStyle(
		color: Colors.lightBlue.shade700,
		decoration: TextDecoration.underline,
		fontWeight: FontWeight.w600,
	);
	return Theme(
		data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
		child: Card(
			margin: const EdgeInsets.symmetric(vertical: 6),
			elevation: 1.5,
			child: ExpansionTile(
				leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
				title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
				childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
				children: [
					const SizedBox(height: 8),
					...children,
					if (footerLinks.isNotEmpty) ...[
						const SizedBox(height: 8),
						Wrap(
							spacing: 8,
							runSpacing: 4,
							children: footerLinks
									.map((f) => TextButton.icon(
																onPressed: () => _openUrl(context, f.url),
																icon: Icon(Icons.open_in_new_rounded, size: 18, color: Colors.lightBlue.shade400),
																label: Text(f.label, style: linkStyle),
															))
									.toList(),
							),
						],
					const SizedBox(height: 8),
				],
			),
		),
	);
}

class _Bullet extends StatelessWidget {
	const _Bullet(this.text);
	final String text;
	@override
	Widget build(BuildContext context) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 4),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					const Padding(
						padding: EdgeInsets.only(top: 6),
						child: Icon(Icons.circle, size: 6, color: Colors.black54),
					),
					const SizedBox(width: 8),
					Expanded(child: Text(text)),
				],
			),
		);
	}
}

class _FooterLink {
	const _FooterLink(this.label, this.url);
	final String label;
	final String url;
}

Widget _linkTile(BuildContext context, {required String label, required String url}) {
	final linkStyle = TextStyle(
		color: Colors.lightBlue.shade700,
		decoration: TextDecoration.underline,
		fontWeight: FontWeight.w600,
	);
	return ListTile(
		contentPadding: EdgeInsets.zero,
		dense: true,
		title: Text(label, style: linkStyle),
		trailing: Icon(Icons.open_in_new_rounded, color: Colors.lightBlue.shade400),
		onTap: () => _openUrl(context, url),
	);
}

Future<void> _openUrl(BuildContext context, String url) async {
	final uri = Uri.parse(url);
	if (await canLaunchUrl(uri)) {
		await launchUrl(uri, mode: LaunchMode.externalApplication);
	} else {
		if (context.mounted) {
			ScaffoldMessenger.of(context).showSnackBar(
				const SnackBar(content: Text('Could not open the link')),
			);
		}
	}
}

class _LanguageMenu extends StatelessWidget {
	const _LanguageMenu({required this.current, required this.onSelect});
	final String current;
	final void Function(String) onSelect;

	@override
	Widget build(BuildContext context) {
		return PopupMenuButton<String>(
			tooltip: 'Change language',
			position: PopupMenuPosition.under,
			itemBuilder: (ctx) => [
				PopupMenuItem(
					value: 'EN',
					child: Row(
						children: const [
							Icon(Icons.check, size: 16, color: Colors.green),
							SizedBox(width: 8),
							Text('English (EN)'),
						],
					),
				),
				const PopupMenuDivider(),
				const PopupMenuItem(
					value: 'TR',
					child: Text('Türkçe (TR)'),
				),
			],
			onSelected: onSelect,
			child: Row(
				children: [
					const Icon(Icons.language),
					const SizedBox(width: 4),
					Text(current, style: const TextStyle(fontWeight: FontWeight.w600)),
					const SizedBox(width: 4),
					const Icon(Icons.arrow_drop_down),
				],
			),
		);
	}
}
