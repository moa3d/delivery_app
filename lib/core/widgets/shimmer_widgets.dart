import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

Widget _shimmerWrap({required Widget child}) {
  return Shimmer.fromColors(
    baseColor: Colors.grey[300]!,
    highlightColor: Colors.grey[100]!,
    child: child,
  );
}

// ─── Wallet ────────────────────────────────────────────────────

class ShimmerWalletSkeleton extends StatelessWidget {
  const ShimmerWalletSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const ShimmerBox(width: double.infinity, height: 160, borderRadius: 32),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 140, borderRadius: 24),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
            const SizedBox(height: 16),
            Row(
              children: const [
                Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 24)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 24)),
              ],
            ),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 64, borderRadius: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Financial Transactions ────────────────────────────────────

class ShimmerTransactionsSkeleton extends StatelessWidget {
  const ShimmerTransactionsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ShimmerBox(width: double.infinity, height: 120, borderRadius: 24),
            const SizedBox(height: 16),
            const ShimmerBox(width: double.infinity, height: 100, borderRadius: 24),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                ShimmerBox(width: 120, height: 50),
                ShimmerBox(width: 80, height: 50),
              ],
            ),
            const SizedBox(height: 24),
            const ShimmerBox(width: double.infinity, height: 220, borderRadius: 24),
            const SizedBox(height: 24),
            Row(
              children: const [
                ShimmerBox(width: 70, height: 40, borderRadius: 12),
                SizedBox(width: 12),
                ShimmerBox(width: 70, height: 40, borderRadius: 12),
                SizedBox(width: 12),
                ShimmerBox(width: 70, height: 40, borderRadius: 12),
                SizedBox(width: 12),
                ShimmerBox(width: 70, height: 40, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 24),
            const ShimmerBox(width: 150, height: 20),
            const SizedBox(height: 16),
            ...List.generate(3, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: ShimmerBox(width: double.infinity, height: 90, borderRadius: 24),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Cash Collection ───────────────────────────────────────────

class ShimmerCashCollectionSkeleton extends StatelessWidget {
  const ShimmerCashCollectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: const [
                      Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 24)),
                      SizedBox(width: 12),
                      Expanded(child: ShimmerBox(width: double.infinity, height: 110, borderRadius: 24)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const ShimmerBox(width: double.infinity, height: 90, borderRadius: 24),
                  const SizedBox(height: 24),
                  Row(
                    children: const [
                      ShimmerBox(width: 60, height: 36, borderRadius: 12),
                      SizedBox(width: 10),
                      ShimmerBox(width: 70, height: 36, borderRadius: 12),
                      SizedBox(width: 10),
                      ShimmerBox(width: 60, height: 36, borderRadius: 12),
                      SizedBox(width: 10),
                      ShimmerBox(width: 65, height: 36, borderRadius: 12),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const ShimmerBox(width: double.infinity, height: 260, borderRadius: 24),
                ],
              ),
            ),
          ),
          const ShimmerBox(width: double.infinity, height: 80),
        ],
      ),
    );
  }
}

// ─── Orders History ────────────────────────────────────────────

class ShimmerOrdersHistorySkeleton extends StatelessWidget {
  const ShimmerOrdersHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: const [
                Expanded(child: ShimmerBox(width: double.infinity, height: 80, borderRadius: 24)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(width: double.infinity, height: 80, borderRadius: 24)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: const [
                ShimmerBox(width: 80, height: 36, borderRadius: 12),
                SizedBox(width: 12),
                ShimmerBox(width: 90, height: 36, borderRadius: 12),
                SizedBox(width: 12),
                ShimmerBox(width: 80, height: 36, borderRadius: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: 4,
              itemBuilder: (_, _) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: ShimmerBox(width: double.infinity, height: 140, borderRadius: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Past Order Details ────────────────────────────────────────

class ShimmerOrderDetailSkeleton extends StatelessWidget {
  const ShimmerOrderDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            ShimmerBox(width: double.infinity, height: 140, borderRadius: 24),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 160, borderRadius: 24),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 160, borderRadius: 24),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 200, borderRadius: 24),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 140, borderRadius: 24),
            SizedBox(height: 16),
            ShimmerBox(width: double.infinity, height: 180, borderRadius: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Settings ──────────────────────────────────────────────────

class ShimmerSettingsSkeleton extends StatelessWidget {
  const ShimmerSettingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _shimmerWrap(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: const [
                ShimmerBox(width: 40, height: 40, borderRadius: 12),
                SizedBox(width: 15),
                ShimmerBox(width: 120, height: 24),
              ],
            ),
            const SizedBox(height: 25),
            const ShimmerBox(width: double.infinity, height: 130, borderRadius: 25),
            const SizedBox(height: 30),
            const ShimmerBox(width: 80, height: 14),
            const SizedBox(height: 10),
            const ShimmerBox(width: double.infinity, height: 180, borderRadius: 20),
            const SizedBox(height: 25),
            const ShimmerBox(width: 90, height: 14),
            const SizedBox(height: 10),
            const ShimmerBox(width: double.infinity, height: 60, borderRadius: 20),
            const SizedBox(height: 25),
            const ShimmerBox(width: 100, height: 14),
            const SizedBox(height: 10),
            const ShimmerBox(width: double.infinity, height: 60, borderRadius: 20),
            const SizedBox(height: 25),
            const ShimmerBox(width: 100, height: 14),
            const SizedBox(height: 10),
            const ShimmerBox(width: double.infinity, height: 120, borderRadius: 20),
            const SizedBox(height: 30),
            const ShimmerBox(width: double.infinity, height: 56, borderRadius: 15),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
