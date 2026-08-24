/*M!999999\- enable the sandbox mode */ 
-- MariaDB dump 10.19-11.8.6-MariaDB, for debian-linux-gnu (x86_64)
--
-- Host: mysql    Database: trade_history
-- ------------------------------------------------------
-- Server version	8.4.11

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*M!100616 SET @OLD_NOTE_VERBOSITY=@@NOTE_VERBOSITY, NOTE_VERBOSITY=0 */;

--
-- Table structure for table `account_rules`
--

DROP TABLE IF EXISTS `account_rules`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `account_rules` (
  `account_id` bigint unsigned NOT NULL,
  `max_daily_loss` decimal(18,2) DEFAULT NULL,
  `max_daily_loss_pct` decimal(5,2) DEFAULT NULL,
  `daily_profit_target` decimal(18,2) DEFAULT NULL,
  `daily_profit_target_pct` decimal(5,2) DEFAULT NULL,
  `max_total_loss_pct` decimal(5,2) DEFAULT NULL,
  `max_risk_per_trade_pct` decimal(5,2) DEFAULT NULL,
  `max_trades_per_day` tinyint unsigned DEFAULT NULL,
  `min_rr` decimal(4,2) DEFAULT NULL,
  `allowed_sessions` json DEFAULT NULL,
  `notes` longtext COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`account_id`),
  CONSTRAINT `account_rules_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `account_rules`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `account_rules` WRITE;
/*!40000 ALTER TABLE `account_rules` DISABLE KEYS */;
INSERT INTO `account_rules` VALUES
(2,200.00,NULL,400.00,NULL,2.00,100.00,2,1.00,'[\"london\", \"tokyo\", \"newyork\", \"sydney\"]',NULL,'2026-08-24 19:04:36','2026-08-24 19:04:36');
/*!40000 ALTER TABLE `account_rules` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `accounts`
--

DROP TABLE IF EXISTS `accounts`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `accounts` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint unsigned NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `broker` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `currency` char(3) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'USD',
  `initial_balance` decimal(18,2) NOT NULL DEFAULT '0.00',
  `started_at` date NOT NULL,
  `is_archived` tinyint(1) NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `accounts_user_id_is_archived_index` (`user_id`,`is_archived`),
  CONSTRAINT `accounts_user_id_foreign` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `accounts`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `accounts` WRITE;
/*!40000 ALTER TABLE `accounts` DISABLE KEYS */;
INSERT INTO `accounts` VALUES
(2,1,'Bersyukur','Exness','USC',5000.00,'2026-07-01',0,'2026-08-24 09:20:54','2026-08-24 09:20:54');
/*!40000 ALTER TABLE `accounts` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `ai_analyses`
--

DROP TABLE IF EXISTS `ai_analyses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `ai_analyses` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `account_id` bigint unsigned NOT NULL,
  `period_start` date NOT NULL,
  `period_end` date NOT NULL,
  `stats_hash` char(40) COLLATE utf8mb4_unicode_ci NOT NULL,
  `result_md` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `model` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `ai_analyses_account_id_stats_hash_unique` (`account_id`,`stats_hash`),
  CONSTRAINT `ai_analyses_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `ai_analyses`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `ai_analyses` WRITE;
/*!40000 ALTER TABLE `ai_analyses` DISABLE KEYS */;
INSERT INTO `ai_analyses` VALUES
(1,2,'2026-07-25','2026-08-24','2155243e7bd14a4f18d5d3ebbc499faad7e7bada','3,47 USC berhasil melampaui rata-rata kerugian. (Wait, avg loss is 89.26, let\'s','gemini-3.5-flash','2026-08-24 18:45:33','2026-08-24 18:45:33'),
(2,2,'2026-07-25','2026-08-24','108713281f0335133062b40f1ffde5c363ccd478','Berikut adalah evaluasi jurnal trading Anda untuk periode 25 Juli 2026 hingga 24 Agustus 2026.\n\n## Ringkasan\nSelama periode ini, Anda telah mengeksekusi sebanyak 46 trade dengan hasil net P/L sebesar 1662.9 USC. Kinerja positif ini didukung oleh winrate yang cukup tinggi sebesar 63% dan profit factor yang sehat di angka 2.1. Berdasarkan data tersebut, periode ini berhasil menumbuhkan modal Anda dari saldo awal 5000 USC menjadi','gemini-3.5-flash','2026-08-24 19:35:13','2026-08-24 19:35:13'),
(3,2,'2026-07-25','2026-08-24','b919210ea3a394776c93d24b336978ac2eac7b6e','## Ringkasan\n\nPeriode ini mencatat total **47** trade dengan P/L bersih sebesar **449.76 USC**, winrate **61.7%**, dan profit factor **1.16**. Kesimpulannya, periode ini menghasilkan modal sebesar **449.76 USC**, di mana tingginya winrate menjadi penentu utama hasil positif ini untuk menutupi buruknya rasio keuntungan dibanding kerugian. Hal yang paling mendesak untuk diperbaiki adalah realisasi *Risk-to-Reward* (RR) yang sangat menyimpang dari rencana awal dan pencatatan setup yang kosong.\n\n## Kualitas eksekusi\n\n*   **Sering Benar vs Menang Besar**: Keuntungan Anda murni datang dari tingginya frekuensi kemenangan (winrate **61.7%**), bukan dari besarnya profit saat menang. Hal ini ditunjukkan oleh payoff ratio yang hanya **0.72** dan ekspektasi per trade sebesar **9.57 USC**.\n*   **Penyimpangan Rencana**: Terjadi jurang pemisah yang sangat lebar antara `avg_rr_planned` sebesar **1.21** dengan `avg_rr_realized` yang hanya **0.24**. Ini membuktikan bahwa Anda menutup posisi jauh lebih awal dari target awal (*cut profit* prematur) atau membiarkan kerugian meluncur melewati batas yang direncanakan.\n*   **Anomali Kerugian**: Perbandingan antara `avg_loss` sebesar **151.7 USC** dengan `largest_loss` sebesar **-1213.14 USC** menunjukkan adanya satu kejadian fatal yang merusak seluruh statistik akun Anda, bukan karena pola kerugian harian yang konsisten.\n\n## Model & strategi\n\nGaya trading Anda adalah spesialisasi satu instrumen (**XAU/USD**) dengan frekuensi transaksi harian yang tinggi di jam-jam acak (pagi hingga malam). Anda sangat condong menahan posisi searah tren kenaikan (*buy*) yang terbukti menghasilkan profit konsisten, namun sangat lemah saat mengambil posisi berlawanan atau menjual (*sell*). Eksekusi RR Anda sangat tidak konsisten dan tidak memiliki dasar teknis yang tercatat karena tidak ada satu pun setup yang didokumentasikan.\n\n| Hari | Jumlah Trade | P/L (USC) | Winrate (%) |\n| :--- | :---: | :---: | :---: |\n| **Senin** | **15** | **-743.74** | **60.0%** |\n| **Selasa** | **10** | **283.60** | **60.0%** |\n| **Kamis** | **9** | **216.40** | **66.7%** |\n| **Rabu** | **6** | **210.90** | **33.3%** |\n| **Jumat** | **5** | **476.20** | **100.0%** |\n| **Sabtu** | **2** | **6.40** | **50.0%** |\n\n**Yang sudah bagus**\n*   Arah transaksi beli (**buy**): Menghasilkan profit **1723.7 USC** dari **28** trade dengan winrate tinggi **71.4%**.\n*   Performa hari Jumat: Menghasilkan profit tertinggi sebesar **476.2 USC** dari **5** trade dengan winrate sempurna **100%**.\n*   Performa jam pagi (**07:00**): Menghasilkan profit **334.5 USC** dari **10** trade dengan winrate **60%**.\n\n**Yang masih kurang**\n*   Arah transaksi jual (**sell**): Mengalami kerugian sebesar **-1273.94 USC** dari **19** trade dengan winrate rendah **47.4%**.\n*   Ketiadaan data setup: Seluruh **47** trade dicatat sebagai **(tanpa setup)**, yang berarti Anda trading secara intuitif tanpa validasi aturan teknis yang konsisten.\n*   Performa hari Senin: Mengalami kerugian terbesar mingguan sebesar **-743.74 USC** dari **15** trade meskipun winrate mencapai **60%**, akibat buruknya manajemen risiko di awal pekan.\n\n## Pola yang menghasilkan\n\n*   Kombinasi **XAU/USD** arah **buy**: Menghasilkan profit bersih **1723.7 USC** dari **28** trade dengan winrate **71.4%**. Ini adalah mesin uang utama Anda periode ini.\n*   Kombinasi transaksi hari Jumat: Menghasilkan profit **476.2 USC** dari **5** trade dengan winrate **100%** (catatan: sampel **5** trade masih terlalu sedikit untuk disimpulkan sebagai pola jangka panjang, namun wajib dipertahankan).\n*   Kombinasi transaksi jam **07:00**: Menghasilkan profit **334.5 USC** dari **10** trade dengan winrate **60%**.\n\n## Pola yang merugikan\n\n*   Kombinasi **XAU/USD** arah **sell**: Mengakibatkan kerugian sebesar **-1273.94 USC** dari **19** trade dengan winrate **47.4%**. Jika Anda mengeliminasi arah ini, Anda bisa menghemat kerugian sebesar **1273.94 USC**.\n*   Kombinasi transaksi jam **20:00**: Mengakibatkan kerugian sebesar **-823.24 USC** dari hanya **3** trade dengan winrate **33.3%** (sampel kecil namun dampaknya sangat merusak).\n*   Kombinasi transaksi hari Senin: Mengakibatkan kerugian sebesar **-743.74 USC** dari **15** trade dengan winrate **60%**, membuktikan bahwa Anda sering menang kecil di hari Senin namun sekali kalah langsung dalam jumlah besar.\n\n## Risiko & disiplin\n\n*   `max_drawdown` tercatat sebesar **1213.14 USC** (**24.26%** dari modal awal), yang dipicu langsung oleh `largest_loss` tunggal sebesar **-1213.14 USC**.\n*   `longest_loss_streak` adalah **4** kali kalah beruntun, dengan posisi terbuka saat ini (`open_trades`) sebanyak **0**.\n*   Pelanggaran aturan (*violations*) terjadi pada **6** hari yang berbeda:\n    1.  \"melebihi jumlah trade harian\" dilanggar sebanyak **5** hari (tanggal **18, 19, 20, 21, dan 24 Agustus 2026**).\n    2.  \"RR di bawah minimum\" dilanggar sebanyak **3** hari (tanggal **19, 20, dan 24 Agustus 2026**).\n    3.  \"melewati batas loss harian\" dilanggar sebanyak **1** hari pada tanggal **17 Agustus 2026**, yang menjadi penyebab utama drawdown terbesar Anda.\n\n> **Peringatan Kritis**: Pelanggaran disiplin beruntun dari tanggal 17 hingga 24 Agustus 2026—khususnya kegagalan membatasi loss harian pada 17 Agustus—telah menghancurkan profitabilitas sistem Anda dan melahirkan drawdown ekstrem sebesar **24.26%** hanya dari satu transaksi tunggal yang tidak terkontrol.\n\n## Langkah berikutnya\n\n1.  Hentikan seluruh transaksi arah **sell** pada instrumen **XAU/USD** minggu depan untuk mengeliminasi potensi kebocoran modal sebesar **-1273.94 USC**.\n2.  Batasi frekuensi trading maksimal **2** trade per hari untuk menghentikan kebiasaan *overtrading* yang melanggar aturan jumlah trade harian pada **5** hari di periode ini.\n3.  Terapkan batas rugi harian ketat sebesar **150 USC** (mendekati `avg_loss` Anda sebesar **151.7 USC**) dan matikan platform trading jika batas ini tersentuh untuk mencegah terulangnya kerugian fatal **-1213.14 USC**.\n4.  Wajibkan rasio RR realisasi minimum sebesar **1.00** per trade dengan cara memasang target profit (TP) dan stop loss (SL) secara otomatis sejak awal, guna mengoreksi penyimpangan `avg_rr_realized` yang saat ini hanya berada di angka **0.24**.\n5.  Hindari membuka posisi baru pada jam **20:00** untuk menghentikan kerugian sebesar **-823.24 USC** yang terjadi pada jam tersebut.\n6.  Wajib menuliskan minimal satu nama pola teknis pada kolom setup untuk setiap trade baru guna menghentikan status **(tanpa setup)** pada **47** transaksi berikutnya.','gemini-3.5-flash','2026-08-24 19:54:29','2026-08-24 19:54:29');
/*!40000 ALTER TABLE `ai_analyses` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `cache`
--

DROP TABLE IF EXISTS `cache`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `value` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `cache` WRITE;
/*!40000 ALTER TABLE `cache` DISABLE KEYS */;
INSERT INTO `cache` VALUES
('trade-history-cache-356a192b7913b04c54574d18c28d46e6395428ab','i:1;',1787572506),
('trade-history-cache-356a192b7913b04c54574d18c28d46e6395428ab:timer','i:1787572506;',1787572506),
('trade-history-cache-77de68daecd823babbb58edb1c8e14d7106e83bb','i:1;',1787572572),
('trade-history-cache-77de68daecd823babbb58edb1c8e14d7106e83bb:timer','i:1787572572;',1787572572),
('trade-history-cache-9336af036f633175f7a5d37c1228f70fd28b04cb','i:1;',1787569170),
('trade-history-cache-9336af036f633175f7a5d37c1228f70fd28b04cb:timer','i:1787569170;',1787569170),
('trade-history-cache-b7ad7f2b04bd98f199a2b8c016e37e66c831b866','i:1;',1787572570),
('trade-history-cache-b7ad7f2b04bd98f199a2b8c016e37e66c831b866:timer','i:1787572570;',1787572570),
('trade-history-cache-gemini:rpd','i:20;',1787652327),
('trade-history-cache-gemini:rpd:timer','i:1787652327;',1787652327),
('trade-history-cache-gemini:rpm','i:1;',1787572507),
('trade-history-cache-gemini:rpm:timer','i:1787572507;',1787572507),
('trade-history-cache-gemini:tpm','i:9640;',1787572529),
('trade-history-cache-gemini:tpm:timer','i:1787572529;',1787572529);
/*!40000 ALTER TABLE `cache` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `cache_locks`
--

DROP TABLE IF EXISTS `cache_locks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `cache_locks` (
  `key` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `expiration` bigint NOT NULL,
  PRIMARY KEY (`key`),
  KEY `cache_locks_expiration_index` (`expiration`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `cache_locks`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `cache_locks` WRITE;
/*!40000 ALTER TABLE `cache_locks` DISABLE KEYS */;
/*!40000 ALTER TABLE `cache_locks` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `failed_jobs`
--

DROP TABLE IF EXISTS `failed_jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `failed_jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `uuid` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `connection` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `exception` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `failed_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `failed_jobs_uuid_unique` (`uuid`),
  KEY `failed_jobs_connection_queue_failed_at_index` (`connection`,`queue`,`failed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `failed_jobs`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `failed_jobs` WRITE;
/*!40000 ALTER TABLE `failed_jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `failed_jobs` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `gemini_settings`
--

DROP TABLE IF EXISTS `gemini_settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `gemini_settings` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `api_key` text COLLATE utf8mb4_unicode_ci,
  `model` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `rpm` int unsigned DEFAULT NULL,
  `tpm` int unsigned DEFAULT NULL,
  `rpd` int unsigned DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `gemini_settings`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `gemini_settings` WRITE;
/*!40000 ALTER TABLE `gemini_settings` DISABLE KEYS */;
INSERT INTO `gemini_settings` VALUES
(1,'eyJpdiI6Im1ST0o2aDRjRE82MWJlV0NLRlIwNEE9PSIsInZhbHVlIjoiQmlaVHNBZTNxTTlBWmxzOFFycGRTa2hBTE1wdjlTZTJUWTZKRHQ0WDVkc0hPN0hpRVBINkRsRk9yMkphTDVBNDVYbXRHemROR1JsaWxEWTVUbmVpQkE9PSIsIm1hYyI6ImE2OTJhZWRjZTQxNmMwMmYwYjM0MTNlOGYwMzY4OWIyNmYxMTFmNTU4NWE0YTI5NDk5NDE0MDJlNmU0MmMwNTYiLCJ0YWciOiIifQ==','gemini-3.5-flash',10,200000,450,'2026-08-24 18:35:23','2026-08-24 18:55:29');
/*!40000 ALTER TABLE `gemini_settings` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `job_batches`
--

DROP TABLE IF EXISTS `job_batches`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `job_batches` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `total_jobs` int NOT NULL,
  `pending_jobs` int NOT NULL,
  `failed_jobs` int NOT NULL,
  `failed_job_ids` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `options` mediumtext COLLATE utf8mb4_unicode_ci,
  `cancelled_at` int DEFAULT NULL,
  `created_at` int NOT NULL,
  `finished_at` int DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `job_batches`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `job_batches` WRITE;
/*!40000 ALTER TABLE `job_batches` DISABLE KEYS */;
/*!40000 ALTER TABLE `job_batches` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `jobs`
--

DROP TABLE IF EXISTS `jobs`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `jobs` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `queue` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `attempts` smallint unsigned NOT NULL,
  `reserved_at` int unsigned DEFAULT NULL,
  `available_at` int unsigned NOT NULL,
  `created_at` int unsigned NOT NULL,
  PRIMARY KEY (`id`),
  KEY `jobs_queue_index` (`queue`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `jobs`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `jobs` WRITE;
/*!40000 ALTER TABLE `jobs` DISABLE KEYS */;
/*!40000 ALTER TABLE `jobs` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `migrations`
--

DROP TABLE IF EXISTS `migrations`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `migrations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `migration` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `batch` int NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=11 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `migrations`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `migrations` WRITE;
/*!40000 ALTER TABLE `migrations` DISABLE KEYS */;
INSERT INTO `migrations` VALUES
(1,'0001_01_01_000000_create_users_table',1),
(2,'0001_01_01_000001_create_cache_table',1),
(3,'0001_01_01_000002_create_jobs_table',1),
(4,'2026_08_24_000001_create_accounts_table',1),
(5,'2026_08_24_000002_create_transactions_table',1),
(6,'2026_08_24_000003_create_trades_table',1),
(7,'2026_08_24_000004_create_account_rules_table',1),
(8,'2026_08_24_000005_create_ai_analyses_table',1),
(9,'2026_08_24_000006_create_admin_and_gemini_settings',2),
(10,'2026_08_24_000007_add_limits_to_gemini_settings',3);
/*!40000 ALTER TABLE `migrations` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `password_reset_tokens`
--

DROP TABLE IF EXISTS `password_reset_tokens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `password_reset_tokens` (
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `token` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `password_reset_tokens`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `password_reset_tokens` WRITE;
/*!40000 ALTER TABLE `password_reset_tokens` DISABLE KEYS */;
/*!40000 ALTER TABLE `password_reset_tokens` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `sessions`
--

DROP TABLE IF EXISTS `sessions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `sessions` (
  `id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `user_id` bigint unsigned DEFAULT NULL,
  `ip_address` varchar(45) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `user_agent` text COLLATE utf8mb4_unicode_ci,
  `payload` longtext COLLATE utf8mb4_unicode_ci NOT NULL,
  `last_activity` int NOT NULL,
  PRIMARY KEY (`id`),
  KEY `sessions_user_id_index` (`user_id`),
  KEY `sessions_last_activity_index` (`last_activity`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sessions`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `sessions` WRITE;
/*!40000 ALTER TABLE `sessions` DISABLE KEYS */;
INSERT INTO `sessions` VALUES
('j6YU78EiOd1737Wp79DFRUjp5HUemkWKLxz7B0vG',3,'172.18.0.1','Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Safari/537.36','eyJfdG9rZW4iOiJIOENtbldvem5jZzhyRTZydEJaclBBWGp1c1k3bE9oMG5tRkkzbktVIiwiX2ZsYXNoIjp7Im9sZCI6W10sIm5ldyI6W119LCJfcHJldmlvdXMiOnsidXJsIjoiaHR0cDpcL1wvbG9jYWxob3N0OjgwMDBcL2xvZ2luIiwicm91dGUiOiJsb2dpbiJ9LCJsb2dpbl93ZWJfNTliYTM2YWRkYzJiMmY5NDAxNTgwZjAxNGM3ZjU4ZWE0ZTMwOTg5ZCI6M30=',1787572510),
('TiytC4gEdyEhiWUBMoloPM0xy4OtSO5LC5Zi3TR6',1,'192.168.1.13','Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/151.0.0.0 Mobile Safari/537.36','eyJfdG9rZW4iOiJyczlINzg0eTBtbDYzWW9SaUxSSWVxUjFtS0kxS1pSOUJESkw4Ymw3IiwiX2ZsYXNoIjp7Im9sZCI6W10sIm5ldyI6W119LCJsb2dpbl93ZWJfNTliYTM2YWRkYzJiMmY5NDAxNTgwZjAxNGM3ZjU4ZWE0ZTMwOTg5ZCI6MSwiY3VycmVudF9hY2NvdW50X2lkIjoyLCJfcHJldmlvdXMiOnsidXJsIjoiaHR0cDpcL1wvMTkyLjE2OC4xLjE0OjgwMDAiLCJyb3V0ZSI6ImRhc2hib2FyZCJ9fQ==',1787572469);
/*!40000 ALTER TABLE `sessions` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `trades`
--

DROP TABLE IF EXISTS `trades`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `trades` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `account_id` bigint unsigned NOT NULL,
  `symbol` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
  `direction` enum('buy','sell') COLLATE utf8mb4_unicode_ci NOT NULL,
  `lot` decimal(10,2) DEFAULT NULL,
  `entry_price` decimal(18,5) DEFAULT NULL,
  `sl_price` decimal(18,5) DEFAULT NULL,
  `tp_price` decimal(18,5) DEFAULT NULL,
  `exit_price` decimal(18,5) DEFAULT NULL,
  `pnl` decimal(18,2) DEFAULT NULL,
  `pips` decimal(10,1) DEFAULT NULL,
  `rr_planned` decimal(6,2) DEFAULT NULL,
  `rr_realized` decimal(6,2) DEFAULT NULL,
  `status` enum('open','win','loss','be') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'open',
  `opened_at` datetime NOT NULL,
  `closed_at` datetime DEFAULT NULL,
  `setup` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `tags` json DEFAULT NULL,
  `notes` text COLLATE utf8mb4_unicode_ci,
  `source` enum('manual','ai') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'manual',
  `ai_raw` json DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `trades_account_id_opened_at_index` (`account_id`,`opened_at`),
  KEY `trades_account_id_status_index` (`account_id`,`status`),
  KEY `trades_account_id_symbol_index` (`account_id`,`symbol`),
  CONSTRAINT `trades_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=259 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `trades`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `trades` WRITE;
/*!40000 ALTER TABLE `trades` DISABLE KEYS */;
INSERT INTO `trades` VALUES
(212,2,'XAU/USD','sell',0.12,4421.47600,4429.58000,4412.54100,4412.54100,107.20,NULL,1.10,1.10,'win','2026-08-18 01:18:00','2026-08-18 01:39:00',NULL,NULL,'Posisi ditutup oleh Batas Untung (Take Profit).','ai',NULL,'2026-08-24 10:29:19','2026-08-24 10:29:19'),
(213,2,'XAU/USD','sell',0.10,4411.04200,4420.79800,4398.91000,4398.91000,121.30,NULL,1.24,1.24,'win','2026-08-18 02:12:00','2026-08-18 02:34:00',NULL,NULL,'Closed by Take Profit (Batas Untung)','ai',NULL,'2026-08-24 10:29:55','2026-08-24 10:29:55'),
(214,2,'XAU/USD','sell',0.13,4404.08700,4410.05100,4396.02600,4410.05100,-77.60,NULL,1.35,-1.00,'loss','2026-08-18 02:48:00','2026-08-18 03:15:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai',NULL,'2026-08-24 10:30:35','2026-08-24 10:30:35'),
(215,2,'XAU/USD','buy',0.11,4415.71500,4406.84200,4424.87000,4424.87000,100.70,NULL,1.03,1.03,'win','2026-08-18 03:22:00','2026-08-18 07:59:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai',NULL,'2026-08-24 10:31:07','2026-08-24 10:31:07'),
(216,2,'XAU/USD','buy',0.16,4430.50000,4424.86300,4436.83900,4424.86300,-90.20,NULL,1.12,-1.00,'loss','2026-08-18 08:28:00','2026-08-18 09:18:00',NULL,NULL,'Closed by Stop Loss (Batas Rugi)','ai',NULL,'2026-08-24 10:31:30','2026-08-24 10:31:30'),
(217,2,'XAU/USD','buy',0.16,4423.25400,4418.36400,4432.61100,4418.36400,-78.30,NULL,1.91,-1.00,'loss','2026-08-18 09:19:00','2026-08-18 09:41:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai',NULL,'2026-08-24 10:31:52','2026-08-24 10:31:52'),
(218,2,'XAU/USD','sell',0.12,4415.05200,4422.70000,4406.49100,4406.49100,102.70,NULL,1.12,1.12,'win','2026-08-18 09:44:00','2026-08-18 09:47:00',NULL,NULL,'Closed by Take Profit (Batas Untung)','ai',NULL,'2026-08-24 10:32:15','2026-08-24 10:32:15'),
(219,2,'XAU/USD','buy',0.09,4402.28500,4392.76500,4414.44900,4392.76500,-85.70,NULL,1.28,-1.00,'loss','2026-08-18 11:03:00','2026-08-18 11:50:00',NULL,NULL,'Closed by Stop Loss (Batas Rugi)','ai',NULL,'2026-08-24 10:33:01','2026-08-24 10:33:01'),
(220,2,'XAU/USD','sell',0.08,4392.66600,4404.53700,4379.34100,4390.80700,14.80,NULL,1.12,0.16,'win','2026-08-18 17:05:00','2026-08-18 20:14:00',NULL,NULL,'Ditutup oleh Pengguna','ai',NULL,'2026-08-24 10:33:19','2026-08-24 10:33:19'),
(221,2,'XAU/USD','sell',0.16,4404.51000,4410.34300,4389.87700,4393.96800,168.70,NULL,2.51,1.81,'win','2026-08-18 21:41:00','2026-08-18 21:47:00',NULL,NULL,'Order ID #4169502144 in USC currency.','ai',NULL,'2026-08-24 10:33:57','2026-08-24 10:33:57'),
(222,2,'XAU/USD','sell',0.05,4344.24700,4363.58500,4338.20700,4363.58500,-96.70,NULL,0.31,-1.00,'loss','2026-08-19 04:00:00','2026-08-19 18:13:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai','{\"lot\": 0.05, \"pnl\": -96.7, \"notes\": \"Ditutup oleh Batas Rugi (Stop Loss)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4363.585, \"tp_price\": 4338.207, \"closed_at\": \"2026-08-19 18:13\", \"direction\": \"sell\", \"opened_at\": \"2026-08-19 04:00\", \"exit_price\": 4363.585, \"entry_price\": 4344.247, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 10:54:41','2026-08-24 10:54:41'),
(223,2,'XAU/USD','sell',0.09,4352.56100,4363.63600,4338.17900,4363.63600,-99.70,NULL,1.30,-1.00,'loss','2026-08-19 11:18:00','2026-08-19 18:13:00',NULL,NULL,'Ditutup oleh Batas Rugi','ai','{\"lot\": 0.09, \"pnl\": -99.7, \"notes\": \"Ditutup oleh Batas Rugi\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4363.636, \"tp_price\": 4338.179, \"closed_at\": \"2026-08-19 18:13\", \"direction\": \"sell\", \"opened_at\": \"2026-08-19 11:18\", \"exit_price\": 4363.636, \"entry_price\": 4352.561, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 10:55:25','2026-08-24 10:55:25'),
(224,2,'XAU/USD','buy',0.29,4364.37300,4361.15500,4367.94300,4367.94300,103.50,NULL,1.11,1.11,'win','2026-08-19 18:15:00','2026-08-19 18:19:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.29, \"pnl\": 103.5, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4361.155, \"tp_price\": 4367.943, \"closed_at\": \"2026-08-19 18:19\", \"direction\": \"buy\", \"opened_at\": \"2026-08-19 18:15\", \"exit_price\": 4367.943, \"entry_price\": 4364.373, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 10:55:45','2026-08-24 10:55:45'),
(225,2,'XAU/USD','buy',0.13,4371.34900,4364.03600,4379.43200,4363.44100,-102.80,NULL,1.11,-1.08,'loss','2026-08-19 19:09:00','2026-08-19 19:42:00',NULL,NULL,'Closed by Stop Loss (Batas Rugi)','ai','{\"lot\": 0.13, \"pnl\": -102.8, \"notes\": \"Closed by Stop Loss (Batas Rugi)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4364.036, \"tp_price\": 4379.432, \"closed_at\": \"2026-08-19 19:42\", \"direction\": \"buy\", \"opened_at\": \"2026-08-19 19:09\", \"exit_price\": 4363.441, \"entry_price\": 4371.349, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 10:56:02','2026-08-24 10:56:02'),
(226,2,'XAU/USD','sell',0.17,4363.82200,4369.30000,4357.18200,4368.06900,-72.20,NULL,1.21,-0.78,'loss','2026-08-19 19:43:00','2026-08-19 20:11:00',NULL,NULL,'Ditutup oleh Pengguna','ai','{\"lot\": 0.17, \"pnl\": -72.2, \"notes\": \"Ditutup oleh Pengguna\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4369.3, \"tp_price\": 4357.182, \"closed_at\": \"2026-08-19 20:11\", \"direction\": \"sell\", \"opened_at\": \"2026-08-19 19:43\", \"exit_price\": 4368.069, \"entry_price\": 4363.822, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 10:56:24','2026-08-24 10:56:24'),
(227,2,'XAU/USD','buy',1.00,4368.09200,4360.15700,4372.88000,4372.88000,478.80,NULL,0.60,0.60,'win','2026-08-19 20:11:00','2026-08-19 20:21:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 1, \"pnl\": 478.8, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4360.157, \"tp_price\": 4372.88, \"closed_at\": \"2026-08-19 20:21\", \"direction\": \"buy\", \"opened_at\": \"2026-08-19 20:11\", \"exit_price\": 4372.88, \"entry_price\": 4368.092, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 10:59:09','2026-08-24 10:59:09'),
(228,2,'XAU/USD','buy',1.00,4497.22100,4489.66900,4505.06300,4498.70600,148.50,NULL,1.04,0.20,'win','2026-08-20 00:52:00','2026-08-20 01:02:00',NULL,NULL,'Ditutup oleh Pengguna','ai','{\"lot\": 1, \"pnl\": 148.5, \"notes\": \"Ditutup oleh Pengguna\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4489.669, \"tp_price\": 4505.063, \"closed_at\": \"2026-08-20 01:02\", \"direction\": \"buy\", \"opened_at\": \"2026-08-20 00:52\", \"exit_price\": 4498.706, \"entry_price\": 4497.221, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:02:17','2026-08-24 11:02:17'),
(229,2,'XAU/USD','buy',0.50,4511.23000,4461.28300,4523.03500,4511.28200,2.60,NULL,0.24,0.00,'win','2026-08-20 03:59:00','2026-08-20 04:20:00',NULL,NULL,'Order ID #4183495629','ai','{\"lot\": 0.5, \"pnl\": 2.6, \"notes\": \"Order ID #4183495629\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4461.283, \"tp_price\": 4523.035, \"closed_at\": \"2026-08-20 04:20\", \"direction\": \"buy\", \"opened_at\": \"2026-08-20 03:59\", \"exit_price\": 4511.282, \"entry_price\": 4511.23, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:02:38','2026-08-24 11:02:38'),
(230,2,'XAU/USD','sell',0.10,4492.95400,4502.18300,4482.78500,4492.14400,8.10,NULL,1.10,0.09,'win','2026-08-20 14:52:00','2026-08-20 16:40:00',NULL,NULL,'Order ID #4186247342','ai','{\"lot\": 0.1, \"pnl\": 8.1, \"notes\": \"Order ID #4186247342\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4502.183, \"tp_price\": 4482.785, \"closed_at\": \"2026-08-20 16:40\", \"direction\": \"sell\", \"opened_at\": \"2026-08-20 14:52\", \"exit_price\": 4492.144, \"entry_price\": 4492.954, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:03:10','2026-08-24 11:03:10'),
(231,2,'XAU/USD','sell',0.15,4466.18000,4472.10600,4458.96100,4472.10600,-88.90,NULL,1.22,-1.00,'loss','2026-08-20 20:44:00','2026-08-20 20:51:00',NULL,NULL,'Ditutup oleh Batas Rugi','ai','{\"lot\": 0.15, \"pnl\": -88.9, \"notes\": \"Ditutup oleh Batas Rugi\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4472.106, \"tp_price\": 4458.961, \"closed_at\": \"2026-08-20 20:51\", \"direction\": \"sell\", \"opened_at\": \"2026-08-20 20:44\", \"exit_price\": 4472.106, \"entry_price\": 4466.18, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:03:45','2026-08-24 11:03:45'),
(232,2,'XAU/USD','buy',0.15,4483.55600,4477.95400,4490.65900,4477.95400,-84.00,NULL,1.27,-1.00,'loss','2026-08-20 21:01:00','2026-08-20 21:04:00',NULL,NULL,'Posisi ditutup oleh Batas Rugi (Stop Loss).','ai','{\"lot\": 0.15, \"pnl\": -84, \"notes\": \"Posisi ditutup oleh Batas Rugi (Stop Loss).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4477.954, \"tp_price\": 4490.659, \"closed_at\": \"2026-08-20 21:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-20 21:01\", \"exit_price\": 4477.954, \"entry_price\": 4483.556, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:04:30','2026-08-24 11:04:30'),
(233,2,'XAU/USD','sell',0.15,4478.50200,4485.49400,4463.47800,4485.49400,-104.90,NULL,2.15,-1.00,'loss','2026-08-20 21:05:00','2026-08-20 21:35:00',NULL,NULL,'Posisi ditutup oleh Batas Rugi (Stop Loss).','ai','{\"lot\": 0.15, \"pnl\": -104.9, \"notes\": \"Posisi ditutup oleh Batas Rugi (Stop Loss).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4485.494, \"tp_price\": 4463.478, \"closed_at\": \"2026-08-20 21:35\", \"direction\": \"sell\", \"opened_at\": \"2026-08-20 21:05\", \"exit_price\": 4485.494, \"entry_price\": 4478.502, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:05:09','2026-08-24 11:05:09'),
(234,2,'XAU/USD','buy',0.12,4484.54500,4477.37800,4493.45100,4493.45100,106.90,NULL,1.24,1.24,'win','2026-08-20 21:52:00','2026-08-20 22:24:00',NULL,NULL,'Ditutup oleh Batas Untung (TP)','ai','{\"lot\": 0.12, \"pnl\": 106.9, \"notes\": \"Ditutup oleh Batas Untung (TP)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4477.378, \"tp_price\": 4493.451, \"closed_at\": \"2026-08-20 22:24\", \"direction\": \"buy\", \"opened_at\": \"2026-08-20 21:52\", \"exit_price\": 4493.451, \"entry_price\": 4484.545, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:05:43','2026-08-24 11:05:43'),
(235,2,'XAU/USD','buy',0.12,4485.09500,4477.14400,4493.53300,4493.53300,101.30,NULL,1.06,1.06,'win','2026-08-20 21:41:00','2026-08-20 22:24:00',NULL,NULL,'Posisi ditutup oleh Batas Untung.','ai','{\"lot\": 0.12, \"pnl\": 101.3, \"notes\": \"Posisi ditutup oleh Batas Untung.\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4477.144, \"tp_price\": 4493.533, \"closed_at\": \"2026-08-20 22:24\", \"direction\": \"buy\", \"opened_at\": \"2026-08-20 21:41\", \"exit_price\": 4493.533, \"entry_price\": 4485.095, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:06:04','2026-08-24 11:06:04'),
(236,2,'XAU/USD','buy',0.12,4482.98000,4477.31900,4493.55000,4493.55000,126.80,NULL,1.87,1.87,'win','2026-08-20 21:51:00','2026-08-20 22:24:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.12, \"pnl\": 126.8, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4477.319, \"tp_price\": 4493.55, \"closed_at\": \"2026-08-20 22:24\", \"direction\": \"buy\", \"opened_at\": \"2026-08-20 21:51\", \"exit_price\": 4493.55, \"entry_price\": 4482.98, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:07:04','2026-08-24 11:07:04'),
(237,2,'XAU/USD','buy',0.08,4511.25900,4500.74700,4523.81700,4519.64700,67.10,NULL,1.19,0.80,'win','2026-08-21 01:05:00','2026-08-21 02:02:00',NULL,NULL,'Order #4191268180 in USC currency.','ai','{\"lot\": 0.08, \"pnl\": 67.1, \"notes\": \"Order #4191268180 in USC currency.\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4500.747, \"tp_price\": 4523.817, \"closed_at\": \"2026-08-21 02:02\", \"direction\": \"buy\", \"opened_at\": \"2026-08-21 01:05\", \"exit_price\": 4519.647, \"entry_price\": 4511.259, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:08:53','2026-08-24 11:08:53'),
(238,2,'XAU/USD','buy',0.23,4527.09100,4523.17900,4531.51400,4531.51400,101.70,NULL,1.13,1.13,'win','2026-08-21 09:21:00','2026-08-21 09:31:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.23, \"pnl\": 101.7, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4523.179, \"tp_price\": 4531.514, \"closed_at\": \"2026-08-21 09:31\", \"direction\": \"buy\", \"opened_at\": \"2026-08-21 09:21\", \"exit_price\": 4531.514, \"entry_price\": 4527.091, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:09:19','2026-08-24 11:09:19'),
(239,2,'XAU/USD','buy',0.23,4519.40800,4516.27600,4523.82800,4523.82800,101.60,NULL,1.41,1.41,'win','2026-08-21 10:12:00','2026-08-21 10:22:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit).','ai','{\"lot\": 0.23, \"pnl\": 101.6, \"notes\": \"Ditutup oleh Batas Untung (Take Profit).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4516.276, \"tp_price\": 4523.828, \"closed_at\": \"2026-08-21 10:22\", \"direction\": \"buy\", \"opened_at\": \"2026-08-21 10:12\", \"exit_price\": 4523.828, \"entry_price\": 4519.408, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:09:45','2026-08-24 11:09:45'),
(240,2,'XAU/USD','buy',0.23,4532.74000,4528.41800,4537.20600,4537.20600,102.70,NULL,1.03,1.03,'win','2026-08-21 11:48:00','2026-08-21 12:01:00',NULL,NULL,'Ditutup oleh Batas Untung (TP)','ai','{\"lot\": 0.23, \"pnl\": 102.7, \"notes\": \"Ditutup oleh Batas Untung (TP)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4528.418, \"tp_price\": 4537.206, \"closed_at\": \"2026-08-21 12:01\", \"direction\": \"buy\", \"opened_at\": \"2026-08-21 11:48\", \"exit_price\": 4537.206, \"entry_price\": 4532.74, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:10:46','2026-08-24 11:10:46'),
(241,2,'XAU/USD','buy',0.15,4592.62500,4586.63100,4599.50200,4599.50200,103.10,NULL,1.15,1.15,'win','2026-08-21 19:08:00','2026-08-21 19:22:00',NULL,NULL,'Trade closed by Take Profit (Batas Untung).','ai','{\"lot\": 0.15, \"pnl\": 103.1, \"notes\": \"Trade closed by Take Profit (Batas Untung).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4586.631, \"tp_price\": 4599.502, \"closed_at\": \"2026-08-21 19:22\", \"direction\": \"buy\", \"opened_at\": \"2026-08-21 19:08\", \"exit_price\": 4599.502, \"entry_price\": 4592.625, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:11:01','2026-08-24 11:11:01'),
(242,2,'XAU/USD','buy',0.15,4615.44400,4608.98200,4622.29800,4622.29800,102.80,NULL,1.06,1.06,'win','2026-08-22 00:14:00','2026-08-22 00:46:00',NULL,NULL,'Closed by Take Profit (Batas Untung)','ai','{\"lot\": 0.15, \"pnl\": 102.8, \"notes\": \"Closed by Take Profit (Batas Untung)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4608.982, \"tp_price\": 4622.298, \"closed_at\": \"2026-08-22 00:46\", \"direction\": \"buy\", \"opened_at\": \"2026-08-22 00:14\", \"exit_price\": 4622.298, \"entry_price\": 4615.444, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:12:31','2026-08-24 11:12:31'),
(243,2,'XAU/USD','buy',0.15,4621.13300,4614.70600,4627.96200,4614.70600,-96.40,NULL,1.06,-1.00,'loss','2026-08-22 01:30:00','2026-08-22 04:17:00',NULL,NULL,'Closed by Stop Loss (Batas Rugi)','ai','{\"lot\": 0.15, \"pnl\": -96.4, \"notes\": \"Closed by Stop Loss (Batas Rugi)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4614.706, \"tp_price\": 4627.962, \"closed_at\": \"2026-08-22 04:17\", \"direction\": \"buy\", \"opened_at\": \"2026-08-22 01:30\", \"exit_price\": 4614.706, \"entry_price\": 4621.133, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:12:56','2026-08-24 11:12:56'),
(244,2,'XAU/USD','buy',0.40,4617.87400,4615.47600,4620.84600,4615.47600,-96.00,NULL,1.24,-1.00,'loss','2026-08-24 07:31:00','2026-08-24 07:33:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai','{\"lot\": 0.4, \"pnl\": -96, \"notes\": \"Ditutup oleh Batas Rugi (Stop Loss)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4615.476, \"tp_price\": 4620.846, \"closed_at\": \"2026-08-24 07:33\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:31\", \"exit_price\": 4615.476, \"entry_price\": 4617.874, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:15:37','2026-08-24 11:15:37'),
(245,2,'XAU/USD','buy',0.20,4616.00700,4611.68800,4621.32500,4611.68800,-86.30,NULL,1.23,-1.00,'loss','2026-08-24 07:34:00','2026-08-24 07:41:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai','{\"lot\": 0.2, \"pnl\": -86.3, \"notes\": \"Ditutup oleh Batas Rugi (Stop Loss)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4611.688, \"tp_price\": 4621.325, \"closed_at\": \"2026-08-24 07:41\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:34\", \"exit_price\": 4611.688, \"entry_price\": 4616.007, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 11:16:35','2026-08-24 11:16:35'),
(246,2,'XAU/USD','sell',0.40,4610.66800,4613.15100,4607.75600,4613.15100,-99.30,NULL,1.17,-1.00,'loss','2026-08-24 07:42:00','2026-08-24 07:48:00',NULL,NULL,'Posisi ditutup oleh Batas Rugi (Stop Loss).','ai','{\"lot\": 0.4, \"pnl\": -99.3, \"notes\": \"Posisi ditutup oleh Batas Rugi (Stop Loss).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4613.151, \"tp_price\": 4607.756, \"closed_at\": \"2026-08-24 07:48\", \"direction\": \"sell\", \"opened_at\": \"2026-08-24 07:42\", \"exit_price\": 4613.151, \"entry_price\": 4610.668, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:05:50','2026-08-24 18:05:50'),
(247,2,'XAU/USD','sell',0.20,4617.59000,4621.55100,4611.10800,4621.55100,-79.20,NULL,1.64,-1.00,'loss','2026-08-24 07:51:00','2026-08-24 07:54:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai','{\"lot\": 0.2, \"pnl\": -79.2, \"notes\": \"Ditutup oleh Batas Rugi (Stop Loss)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4621.551, \"tp_price\": 4611.108, \"closed_at\": \"2026-08-24 07:54\", \"direction\": \"sell\", \"opened_at\": \"2026-08-24 07:51\", \"exit_price\": 4621.551, \"entry_price\": 4617.59, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:06:34','2026-08-24 18:06:34'),
(248,2,'XAU/USD','buy',0.20,4622.97100,4616.63100,4627.37400,4627.37400,88.10,NULL,0.69,0.69,'win','2026-08-24 07:56:00','2026-08-24 08:04:00',NULL,NULL,'Posisi ditutup oleh Batas Untung (Take Profit).','ai','{\"lot\": 0.2, \"pnl\": 88.1, \"notes\": \"Posisi ditutup oleh Batas Untung (Take Profit).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4616.631, \"tp_price\": 4627.374, \"closed_at\": \"2026-08-24 08:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:56\", \"exit_price\": 4627.374, \"entry_price\": 4622.971, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:07:13','2026-08-24 18:07:13'),
(249,2,'XAU/USD','buy',0.20,4620.66300,4616.39600,4627.39900,4627.39900,134.70,NULL,1.58,1.58,'win','2026-08-24 07:54:00','2026-08-24 08:04:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.2, \"pnl\": 134.7, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4616.396, \"tp_price\": 4627.399, \"closed_at\": \"2026-08-24 08:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:54\", \"exit_price\": 4627.399, \"entry_price\": 4620.663, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:07:50','2026-08-24 18:07:50'),
(250,2,'XAU/USD','buy',0.20,4621.54900,4616.56300,4627.46200,4627.46200,118.20,NULL,1.19,1.19,'win','2026-08-24 07:54:00','2026-08-24 08:04:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.2, \"pnl\": 118.2, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4616.563, \"tp_price\": 4627.462, \"closed_at\": \"2026-08-24 08:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:54\", \"exit_price\": 4627.462, \"entry_price\": 4621.549, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:08:15','2026-08-24 18:08:15'),
(251,2,'XAU/USD','buy',0.20,4623.57000,4616.54500,4627.43500,4627.43500,77.30,NULL,0.55,0.55,'win','2026-08-24 07:56:00','2026-08-24 08:04:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.2, \"pnl\": 77.3, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4616.545, \"tp_price\": 4627.435, \"closed_at\": \"2026-08-24 08:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:56\", \"exit_price\": 4627.435, \"entry_price\": 4623.57, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:08:35','2026-08-24 18:08:35'),
(252,2,'XAU/USD','buy',0.20,4620.54600,4616.52500,4627.46900,4627.46900,138.50,NULL,1.72,1.72,'win','2026-08-24 07:54:00','2026-08-24 08:04:00',NULL,NULL,'Closed by Take Profit (Batas Untung).','ai','{\"lot\": 0.2, \"pnl\": 138.5, \"notes\": \"Closed by Take Profit (Batas Untung).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4616.525, \"tp_price\": 4627.469, \"closed_at\": \"2026-08-24 08:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:54\", \"exit_price\": 4627.469, \"entry_price\": 4620.546, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:09:04','2026-08-24 18:09:04'),
(253,2,'XAU/USD','buy',0.20,4620.54600,4616.52500,4627.46900,4627.46900,138.50,NULL,1.72,1.72,'win','2026-08-24 07:54:00','2026-08-24 08:04:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.2, \"pnl\": 138.5, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4616.525, \"tp_price\": 4627.469, \"closed_at\": \"2026-08-24 08:04\", \"direction\": \"buy\", \"opened_at\": \"2026-08-24 07:54\", \"exit_price\": 4627.469, \"entry_price\": 4620.546, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:09:33','2026-08-24 18:09:33'),
(254,2,'XAU/USD','sell',0.20,4638.17700,4643.00600,4632.74600,4632.74600,108.60,NULL,1.12,1.12,'win','2026-08-24 10:44:00','2026-08-24 10:47:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit).','ai','{\"lot\": 0.2, \"pnl\": 108.6, \"notes\": \"Ditutup oleh Batas Untung (Take Profit).\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4643.006, \"tp_price\": 4632.746, \"closed_at\": \"2026-08-24 10:47\", \"direction\": \"sell\", \"opened_at\": \"2026-08-24 10:44\", \"exit_price\": 4632.746, \"entry_price\": 4638.177, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:10:09','2026-08-24 18:10:09'),
(255,2,'XAU/USD','sell',0.20,4639.94200,4643.89800,4634.88500,4643.89800,-79.20,NULL,1.28,-1.00,'loss','2026-08-24 16:56:00','2026-08-24 17:06:00',NULL,NULL,'Closed by Stop Loss (Batas Rugi)','ai','{\"lot\": 0.2, \"pnl\": -79.2, \"notes\": \"Closed by Stop Loss (Batas Rugi)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4643.898, \"tp_price\": 4634.885, \"closed_at\": \"2026-08-24 17:06\", \"direction\": \"sell\", \"opened_at\": \"2026-08-24 16:56\", \"exit_price\": 4643.898, \"entry_price\": 4639.942, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:10:29','2026-08-24 18:10:29'),
(256,2,'XAU/USD','sell',0.20,4640.26800,4645.17300,4635.14700,4635.14700,102.50,NULL,1.04,1.04,'win','2026-08-24 17:08:00','2026-08-24 17:18:00',NULL,NULL,'Ditutup oleh Batas Untung (Take Profit)','ai','{\"lot\": 0.2, \"pnl\": 102.5, \"notes\": \"Ditutup oleh Batas Untung (Take Profit)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4645.173, \"tp_price\": 4635.147, \"closed_at\": \"2026-08-24 17:18\", \"direction\": \"sell\", \"opened_at\": \"2026-08-24 17:08\", \"exit_price\": 4635.147, \"entry_price\": 4640.268, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 18:10:42','2026-08-24 18:10:42'),
(257,2,'XAU/USD','sell',0.15,4611.13600,4610.93600,4604.12600,4610.93600,3.00,NULL,NULL,NULL,'win','2026-08-24 06:43:00','2026-08-24 07:21:00',NULL,NULL,'Ditutup oleh Batas Rugi (Stop Loss)','ai','{\"lot\": 0.15, \"pnl\": 3, \"notes\": \"Ditutup oleh Batas Rugi (Stop Loss)\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4610.936, \"tp_price\": 4604.126, \"closed_at\": \"2026-08-24 07:21\", \"direction\": \"sell\", \"opened_at\": \"2026-08-24 06:43\", \"exit_price\": 4610.936, \"entry_price\": 4611.136, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 19:34:07','2026-08-24 19:34:07'),
(258,2,'XAU/USD','sell',0.70,4391.32100,4411.95500,4369.82700,4411.95500,-1213.14,NULL,1.04,-1.00,'loss','2026-08-17 20:26:00','2026-08-17 21:57:00',NULL,NULL,'Ditutup oleh Batas Rugi','ai','{\"lot\": 0.7, \"pnl\": -1444.4, \"notes\": \"Ditutup oleh Batas Rugi\", \"setup\": null, \"symbol\": \"XAU/USD\", \"sl_price\": 4411.955, \"tp_price\": 4369.827, \"closed_at\": \"2026-08-17 21:57\", \"direction\": \"sell\", \"opened_at\": \"2026-08-17 20:26\", \"exit_price\": 4411.955, \"entry_price\": 4391.321, \"is_trade_screenshot\": true, \"low_confidence_fields\": []}','2026-08-24 19:51:28','2026-08-24 19:52:46');
/*!40000 ALTER TABLE `trades` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `transactions`
--

DROP TABLE IF EXISTS `transactions`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `account_id` bigint unsigned NOT NULL,
  `type` enum('deposit','withdrawal') COLLATE utf8mb4_unicode_ci NOT NULL,
  `amount` decimal(18,2) NOT NULL,
  `occurred_at` date NOT NULL,
  `proof_path` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `note` text COLLATE utf8mb4_unicode_ci,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `transactions_account_id_occurred_at_index` (`account_id`,`occurred_at`),
  CONSTRAINT `transactions_account_id_foreign` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=7 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `transactions`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `transactions` WRITE;
/*!40000 ALTER TABLE `transactions` DISABLE KEYS */;
/*!40000 ALTER TABLE `transactions` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `email_verified_at` timestamp NULL DEFAULT NULL,
  `password` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `is_admin` tinyint(1) NOT NULL DEFAULT '0',
  `remember_token` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `users_email_unique` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, @@AUTOCOMMIT=0;
LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES
(1,'Ilmi Faizan','ilmifaizan1112@gmail.com',NULL,'$2y$12$gpuHBQYSYBtgrSlVPyQjneA9CRK.VZD1fS.T6kPXmeQEgpsai2rxW',0,NULL,'2026-08-24 09:06:32','2026-08-24 18:56:18'),
(3,'Administrator','admin@gmail.com',NULL,'$2y$12$6clBoZGpKVfkWI76a62H.uXZXYmeioKuQhSlSWCD1bAzhARZqcx1W',1,NULL,'2026-08-24 18:35:50','2026-08-24 18:35:50');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
COMMIT;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*M!100616 SET NOTE_VERBOSITY=@OLD_NOTE_VERBOSITY */;

-- Dump completed on 2026-08-24 11:55:12
