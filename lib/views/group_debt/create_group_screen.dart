import 'package:material_ui/material_ui.dart';
import '../../controllers/group_debt_controller.dart';
import '../widgets/ui_kit.dart';
import 'invite_member_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GroupDebtController _controller = GroupDebtController();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên nhóm');
      return;
    }
    setState(() => _saving = true);
    String? id;
    final ok = await runGuarded(context, () async {
      id = await _controller.createGroup(name, const [], _desc.text);
    });
    if (!mounted) return;
    if (ok && id != null) {
      // Chuyển sang bước mời thành viên.
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => InviteMemberScreen(groupId: id!)));
    } else {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: 'Tạo nhóm',
      bottom: BottomPrimary(text: 'Tạo nhóm', onPressed: _create, loading: _saving),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(
            label: 'Tên nhóm',
            controller: _name,
            icon: Icons.groups_outlined,
            hint: 'Ví dụ: Du lịch Đà Lạt',
            errorText: _error,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          LabeledInput(label: 'Mô tả', controller: _desc, icon: Icons.notes_rounded, hint: 'Ví dụ: Chuyến đi 3 ngày 2 đêm'),
          const SizedBox(height: 16),
          const InfoBanner(
            icon: Icons.person_outline_rounded,
            title: 'Bạn là chủ nhóm',
            subtitle: 'Có thể mời thêm thành viên sau khi tạo',
          ),
        ],
      ),
    );
  }
}
