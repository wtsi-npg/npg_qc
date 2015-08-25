-- Changes for library MQC
--
-- Table structure for table `mqc_library_outcome_ent`
--
CREATE TABLE IF NOT EXISTS `mqc_library_outcome_ent` (
  `id_mqc_library_outcome_ent` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_run` BIGINT(20) UNSIGNED NOT NULL,
  `position` TINYINT(3) UNSIGNED NOT NULL COMMENT 'Lane',
  `tag_index` BIGINT(20) NOT NULL,
  `id_mqc_outcome` SMALLINT UNSIGNED NOT NULL,
  `username` CHAR(128) NULL DEFAULT NULL COMMENT 'Web interface username',
  `last_modified` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_by` CHAR(128) NULL COMMENT 'Last user to modify the row',
  `reported` TIMESTAMP NULL DEFAULT NULL COMMENT 'When was reported to LIMS',
  PRIMARY KEY (`id_mqc_library_outcome_ent`),
  UNIQUE KEY `id_run_UNIQUE` (`id_run`,`position`,`tag_index`),
  KEY `fk_mqc_library_outcome_ent_mqc_outcome_dict1_idx` (`id_mqc_outcome`),
  CONSTRAINT `fk_mqc_library_outcome_ent_mqc_outcome_dict1` FOREIGN KEY (`id_mqc_outcome`) REFERENCES `mqc_outcome_dict` (`id_mqc_outcome`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB
COMMENT = 'Entity table for library manual qc';
--
-- Table structure for table `mqc_library_outcome_hist`
--
CREATE TABLE IF NOT EXISTS `mqc_library_outcome_hist` (
  `id_mqc_library_outcome_hist` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
  `id_run` BIGINT(20) UNSIGNED NOT NULL,
  `position` TINYINT(3) UNSIGNED NOT NULL COMMENT 'Lane',
  `tag_index` BIGINT(20) NOT NULL,
  `id_mqc_outcome` SMALLINT UNSIGNED NOT NULL,
  `username` CHAR(128) NULL DEFAULT NULL COMMENT 'Web interface username',
  `last_modified` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `modified_by` CHAR(128) NULL COMMENT 'Last user to modify the row',
  PRIMARY KEY (`id_mqc_library_outcome_hist`),
  KEY `fk_mqc_library_outcome_hist_mqc_outcome_dict1_idx` (`id_mqc_outcome`),
  CONSTRAINT `fk_mqc_library_outcome_ent_mqc_outcome_dict10` FOREIGN KEY (`id_mqc_outcome`) REFERENCES `mqc_outcome_dict` (`id_mqc_outcome`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE = InnoDB
COMMENT = 'Historic table for library manual qc';

