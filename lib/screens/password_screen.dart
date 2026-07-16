import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import 'home_screen.dart';

class PasswordScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  final bool isSetup;

  const PasswordScreen({
    super.key,
    required this.onAuthenticated,
    this.isSetup = false,
  });

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  String _password = '';
  String? _error;
  bool _isSetup = false;
  bool _isConfirming = false;
  String _firstPassword = '';

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    final db = DatabaseHelper.instance;
    final hasPassword = await db.getSetting('app_password');
    setState(() {
      _isSetup = hasPassword == null || hasPassword.isEmpty;
    });
  }

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'delete') {
        if (_password.isNotEmpty) {
          _password = _password.substring(0, _password.length - 1);
        }
      } else if (_password.length < 8) {
        _password += key;
      }
      _error = null;
    });
  }

  Future<void> _verifyPassword() async {
    if (_password.length < 4) {
      setState(() => _error = '密码至少4位');
      return;
    }
    
    final db = DatabaseHelper.instance;
    final stored = await db.getSetting('app_password');
    if (stored == _password) {
      widget.onAuthenticated();
    } else {
      setState(() {
        _error = '密码错误';
        _password = '';
      });
    }
  }

  Future<void> _onSubmit() async {
    if (_password.length < 4) {
      setState(() => _error = '密码至少4位');
      return;
    }

    if (_isSetup) {
      if (!_isConfirming) {
        setState(() {
          _firstPassword = _password;
          _password = '';
          _isConfirming = true;
          _error = null;
        });
      } else {
        if (_password == _firstPassword) {
          final db = DatabaseHelper.instance;
          await db.setSetting('app_password', _password);
          widget.onAuthenticated();
        } else {
          setState(() {
            _error = '两次密码不一致';
            _password = '';
            _isConfirming = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Icon(
              Icons.lock_outline,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _isSetup
                  ? (_isConfirming ? '确认密码' : '设置密码')
                  : '输入密码',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isSetup ? '设置4-8位数字密码' : '请输入密码以继续',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            // Password dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(8, (i) {
                final filled = i < _password.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withOpacity(0.3),
                  ),
                );
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14)),
            ],
            const Spacer(flex: 1),
            // Numpad
            _buildNumpad(theme),
            const SizedBox(height: 16),
            if (_password.length >= 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FilledButton(
                  onPressed: _isSetup ? _onSubmit : _verifyPassword,
                  child: Text(_isSetup ? (_isConfirming ? '确认' : '下一步') : '确认'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumpad(ThemeData theme) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'delete'],
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: keys.map((row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) return const SizedBox(width: 72);
                return SizedBox(
                  width: 72,
                  height: 56,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _onKeyPress(key),
                      child: Center(
                        child: key == 'delete'
                            ? const Icon(Icons.backspace_outlined, size: 24)
                            : Text(
                                key,
                                style: const TextStyle(
                                    fontSize: 28, fontWeight: FontWeight.w500),
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
