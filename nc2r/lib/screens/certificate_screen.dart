import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../widgets/app_logo.dart';
import '../widgets/tap_scale.dart';

class CertificateScreen extends ConsumerStatefulWidget {
  final String? certificateUrl;

  const CertificateScreen({super.key, this.certificateUrl});

  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3))
      ..play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _openCertificate(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the certificate.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).value;
    final url = widget.certificateUrl ?? user?.certificateUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Certificate')),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AnimatedAppLogo(size: 96),
                      const SizedBox(height: 20),
                      Text('Course Completed!',
                          style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(
                        user?.name ?? '',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'NC II Reviewer — Computer Systems Servicing',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      PressableScale(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('View / Download Certificate'),
                          onPressed:
                              url == null ? null : () => _openCertificate(url),
                        ),
                      ),
                      if (url == null)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Certificate is being generated…'),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.06,
              numberOfParticles: 20,
              maxBlastForce: 20,
              minBlastForce: 8,
              gravity: 0.3,
              colors: const [
                Color(0xFF800000),
                Color(0xFFFFD700),
                Color(0xFFB03030),
                Color(0xFFC9A227),
                Colors.white,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
