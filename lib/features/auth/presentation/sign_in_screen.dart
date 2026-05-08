import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 32),
            const Icon(Icons.child_friendly,
                size: 72, color: Color(0xFFFFAFA3)),
            const SizedBox(height: 8),
            const Text(
              '보미다이어리',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tab,
              tabs: const [Tab(text: '로그인'), Tab(text: '회원가입')],
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: const [_LoginForm(), _SignUpForm()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithUsername(
            username: _username.text,
            password: _password.text,
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(context, _authErrorMessage(e));
    } catch (e) {
      if (mounted) _showError(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _UsernameField(controller: _username),
          const SizedBox(height: 12),
          _PasswordField(controller: _password, onSubmitted: (_) => _submit()),
          const Spacer(),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(_busy ? '로그인 중...' : '로그인'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SignUpForm extends ConsumerStatefulWidget {
  const _SignUpForm();

  @override
  ConsumerState<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<_SignUpForm> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _invite.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signUpWithUsername(
            username: _username.text,
            password: _password.text,
            inviteCode: _invite.text.trim().isEmpty ? null : _invite.text.trim(),
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(context, _authErrorMessage(e));
    } catch (e) {
      if (mounted) _showError(context, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _UsernameField(controller: _username),
          const SizedBox(height: 12),
          _PasswordField(controller: _password),
          const SizedBox(height: 24),
          TextField(
            controller: _invite,
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.digitsOnly,
            ],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '(선택) 초대코드',
              helperText: '가족이 보낸 6자리 코드가 있으면 입력하세요',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: Text(_busy ? '가입 중...' : '회원가입'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autocorrect: false,
      enableSuggestions: false,
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.visiblePassword,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
        LengthLimitingTextInputFormatter(30),
      ],
      decoration: const InputDecoration(
        labelText: '아이디',
        helperText: '영문 소문자/숫자/_ 3–30자',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller, this.onSubmitted});
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: '비밀번호',
        helperText: '6자 이상',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String _authErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-username':
      return e.message ?? '아이디 형식이 올바르지 않습니다.';
    case 'email-already-in-use':
      return '이미 사용 중인 아이디입니다.';
    case 'weak-password':
      return '비밀번호는 6자 이상이어야 합니다.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return '아이디 또는 비밀번호가 올바르지 않습니다.';
    case 'too-many-requests':
      return '잠시 후 다시 시도해주세요.';
    case 'network-request-failed':
      return '네트워크 연결을 확인해주세요.';
    default:
      return e.message ?? '로그인 오류 (${e.code})';
  }
}
