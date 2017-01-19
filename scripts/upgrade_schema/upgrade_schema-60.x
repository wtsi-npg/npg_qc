--
-- Table structure for table `rna_seqc`
--

CREATE TABLE `rna_seqc` (
  `id_rna_seqc` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto-generated primary key',
  `id_seq_composition` bigint(20) unsigned NOT NULL COMMENT 'A foreign key referencing the id_seq_composition column of the seq_composition table',
  `info` text,
  `rrna` float unsigned DEFAULT NULL,
  `rrna_rate` float unsigned DEFAULT NULL,
  `exonic_rate` float unsigned DEFAULT NULL,
  `expression_profiling_efficiency` float unsigned DEFAULT NULL,
  `genes_detected` float unsigned DEFAULT NULL,
  `end_1_sense` float unsigned DEFAULT NULL,
  `end_1_antisense` float unsigned DEFAULT NULL,
  `end_2_sense` float unsigned DEFAULT NULL,
  `end_2_antisense` float unsigned DEFAULT NULL,
  `end_1_pct_sense` float unsigned DEFAULT NULL,
  `end_2_pct_sense` float unsigned DEFAULT NULL,
  `mean_per_base_cov` float unsigned DEFAULT NULL,
  `mean_cv` float unsigned DEFAULT NULL,
  `end_5_norm` float unsigned DEFAULT NULL,
  `end_3_norm` float unsigned DEFAULT NULL,
  `other_metrics` text,
  PRIMARY KEY (`id_rna_seqc`),
  UNIQUE KEY `rna_seqc_id_compos_unq` (`id_seq_composition`),
  KEY `rna_seqc_compos` (`id_seq_composition`),
  CONSTRAINT `rna_seqc_compos` FOREIGN KEY (`id_seq_composition`) REFERENCES `seq_composition` (`id_seq_composition`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
--
--
--
GRANT SELECT ON `rna_seqc` TO nqcro;

