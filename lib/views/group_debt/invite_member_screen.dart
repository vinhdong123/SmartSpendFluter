import 'package:material_ui/material_ui.dart';
import '../../core/constants/app_colors.dart';
import '../../controllers/group_debt_controller.dart';
import '../../models/group_models.dart';
import '../widgets/common_widgets.dart';
import '../widgets/ui_kit.dart';

class InviteMemberScreen extends StatefulWidget {
  final String groupId;
  const InviteMemberScreen({super.key, required this.groupId});

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final GroupDebtController _controller = GroupDebtController();
  final _input = TextEditingController();
  GroupDetail? _group;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final g = await _controller.fetchGroup(widget.groupId);
    if (mounted) setState(() => _group = g);
  }

  Future<void> _invite() async {
    final text = _input.text.trim();
    if (text.isEmpty) {
      showSnack(context, 'Nhập email hoặc tên người cần mời', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      String message;
      if (text.contains('@') && _controller.canShareGroups) {
        final name = await _controller.addMemberByEmail(widget.groupId, text);
        message = 'Đã thêm $name vào nhóm';
      } else {
        // Không có tài khoản / chưa đăng nhập Firebase: thêm như người liên hệ trên máy.
        if (text.contains('@')) {
          message = 'Đã thêm "$text" như người liên hệ (đăng nhập Firebase để mời người dùng thật qua email)';
        } else {
          message = 'Đã thêm $text vào nhóm';
        }
        await _controller.addMember(widget.groupId, text);
      }
      _input.clear();
      await _load();
      if (mounted) showSnack(context, message);
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = _group;
    return SubPage(
      title: 'Mời thành viên',
      bottom: BottomPrimary(text: 'Gửi lời mời', onPressed: _invite, loading: _sending),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabeledInput(
            label: 'Email hoặc tên thành viên',
            controller: _input,
            icon: Icons.person_add_alt_outlined,
            hint: 'minh@email.com',
            keyboardType: TextInputType.emailAddress,
            capitalization: TextCapitalization.none,
          ),
          const SectionLabel('Thành viên hiện tại'),
          if (g == null)
            const Center(child: CircularProgressIndicator(color: AppColors.primary))
          else
            ListCard(
              children: [
                for (var i = 0; i < g.members.length; i++)
                  ListRow(
                    leading: const IconBadge(icon: Icons.person_outline_rounded, size: 48),
                    title: g.members[i].isMe ? '${g.members[i].name == 'Bạn' ? 'Bạn' : g.members[i].name} (bạn)' : g.members[i].name,
                    subtitle: g.members[i].isMe ? 'Chủ nhóm' : 'Đã tham gia',
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
