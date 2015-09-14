CREATE TABLE `seq_component` (
  `id_seq_component`    BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Auto-generated primary key',
  `id_run`              BIGINT(20) UNSIGNED NOT NULL COMMENT 'Numeric run id',
  `position`            TINYINT(1) UNSIGNED NOT NULL COMMENT 'Numeric position (lane number)',
  `tag_index`           MEDIUMINT UNSIGNED  DEFAULT NULL COMMENT 'An optional numeric tag index',
  `subset`              VARCHAR(10)         DEFAULT NULL COMMENT 'An optional sequence subset',
  `digest`              CHAR(64) NOT NULL COMMENT 'A SHA256 hex digest of the component JSON representation as defined in npg_tracking::glossary::composition::component',
  PRIMARY KEY (`id_seq_component`),
  UNIQUE KEY `unq_seq_compon_d` (`digest`),
  INDEX `unq_seq_compos_rp` (`id_run`, `position`, `tag_index`, `subset`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

CREATE TABLE `seq_composition` (
  `id_seq_composition` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Auto-generated primary key',
  `digest`             CHAR(64) NOT NULL COMMENT 'A SHA256 hex digest of the JSON representation of the composition as defined in npg_tracking::glossary::composition',
  `size`               TINYINT UNSIGNED NOT NULL COMMENT 'Total number of components in a composition',
  PRIMARY KEY (`id_seq_composition`),
  UNIQUE KEY `unq_seq_compos_d` (`digest`),
  UNIQUE KEY `unq_seq_compos_ps` (`id_seq_composition`, `size`) /* To allow for a composite foreign key in seq_component_composition */
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

CREATE TABLE `seq_component_composition` (
  `id_seq_comcom`      BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Auto-generated primary key',
  `id_seq_component`   BIGINT(20) UNSIGNED NOT NULL COMMENT 'A foreign key referencing the id_seq_component column of the seq_component table',
  `id_seq_composition` BIGINT(20) UNSIGNED NOT NULL COMMENT 'A foreign key referencing the id_seq_composition column of the seq_composition table',
  `size`               TINYINT UNSIGNED NOT NULL    COMMENT 'Total number of components in a composition',
  PRIMARY KEY (`id_seq_comcom`),
  UNIQUE KEY `unq_seq_comcom` (`id_seq_component`, `id_seq_composition`),
  CONSTRAINT `seq_comcom_cmpon` FOREIGN KEY (`id_seq_component`)   REFERENCES `seq_component` (`id_seq_component`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  CONSTRAINT `seq_comcom_cmpos` FOREIGN KEY (`id_seq_composition`, `size`) REFERENCES `seq_composition` (`id_seq_composition`, `size`) ON DELETE NO ACTION ON UPDATE NO ACTION
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;

CREATE TABLE `sequence_summary` (
  `id_sequence_summary` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Auto-generated primary key',
  `id_seq_composition`  BIGINT(20) UNSIGNED NOT NULL COMMENT 'A foreign key referencing the id_seq_composition column of the seq_composition table',
  `sequence_format`     VARCHAR(6)          NOT NULL COMMENT 'Sequencing file format, e.g. SAM, BAM',
  `header`              TEXT NOT NULL COMMENT 'File header, excluding SQ lines, the field is searchable',
  `seqchksum`           TEXT NOT NULL COMMENT 'Alignment and header independent sequence file digest, see bamseqchksum in https://github.com/wtsi-npg/biobambam, default checksum',
  `seqchksum_sha512`    TEXT NOT NULL COMMENT 'Alignment and header independent sequence file digest, see bamseqchksum in https://github.com/wtsi-npg/biobambam, sha512primesums512 checksum',
  `md5`                 CHAR(32) NOT NULL COMMENT 'md5 of the sequence file',
  `date`                TIMESTAMP NOT NULL COMMENT 'Date the record was created',
  `iscurrent`           TINYINT(1) UNSIGNED NOT NULL DEFAULT 1 COMMENT 'Boolean flag to indicate that the record is current, defaults to 1',
  PRIMARY KEY (`id_sequence_summary`),
  CONSTRAINT `seq_sum_compos` FOREIGN KEY (`id_seq_composition`) REFERENCES `seq_composition` (`id_seq_composition`) ON DELETE NO ACTION ON UPDATE NO ACTION
  /* FULLTEXT `seqsum_h` (`header`) -- cannot have with InnoDB engine unless server version 5.6 */
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;


CREATE TABLE `samtools_stats` (
  `id_samtools_stats`   BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT 'Auto-generated primary key',
  `id_seq_composition`  BIGINT(20) UNSIGNED NOT NULL COMMENT 'A foreign key referencing the id_seq_composition column of the seq_composition table',
  `filter`              VARCHAR(8) NOT NULL COMMENT 'Filter used to produce the stats file',
  `stats`               MEDIUMBLOB NOT NULL COMMENT 'Compressed samtools stats file content',
  PRIMARY KEY (`id_samtools_stats`),
  CONSTRAINT `seq_sum_compos_ss` FOREIGN KEY (`id_seq_composition`) REFERENCES `seq_composition` (`id_seq_composition`) ON DELETE NO ACTION ON UPDATE NO ACTION,
  UNIQUE KEY `unq_seqstats` (`id_seq_composition`,`filter`)
) ENGINE=InnoDB  DEFAULT CHARSET=latin1;
