-- Changes for new dictionary for plex level library MQC
--
-- Table structure for table `mqc_library_outcome_dict`
--
CREATE TABLE `mqc_library_outcome_dict` (
  `id_mqc_library_outcome` smallint(5) unsigned NOT NULL AUTO_INCREMENT,
  `short_desc` varchar(50) NOT NULL,
  `long_desc` varchar(150) DEFAULT NULL,
  `iscurrent` tinyint(1) DEFAULT NULL COMMENT 'Catalog value still in use.',
  `isvisible` tinyint(1) DEFAULT NULL COMMENT 'Is it visible in UI',
  PRIMARY KEY (`id_mqc_library_outcome`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Dictionary table for plex level library MQC';
--
-- Loading dictionary
--
INSERT INTO `mqc_library_outcome_dict` (`id_mqc_library_outcome`, `short_desc`, `long_desc`, `iscurrent`, `isvisible`) VALUES (1, 'Accepted preliminary', 'Library is accepted preliminary', 1, 1) ON DUPLICATE KEY UPDATE iscurrent=1; 
INSERT INTO `mqc_library_outcome_dict` (`id_mqc_library_outcome`, `short_desc`, `long_desc`, `iscurrent`, `isvisible`) VALUES (2, 'Rejected preliminary', 'Library is preliminary rejected.', 1, 1) ON DUPLICATE KEY UPDATE iscurrent=1; 
INSERT INTO `mqc_library_outcome_dict` (`id_mqc_library_outcome`, `short_desc`, `long_desc`, `iscurrent`, `isvisible`) VALUES (3, 'Accepted final', 'Library has been accepted as a final decision.', 1, 1) ON DUPLICATE KEY UPDATE iscurrent=1; 
INSERT INTO `mqc_library_outcome_dict` (`id_mqc_library_outcome`, `short_desc`, `long_desc`, `iscurrent`, `isvisible`) VALUES (4, 'Rejected final', 'Library has been rejected as a final decision.', 1, 1) ON DUPLICATE KEY UPDATE iscurrent=1; 
INSERT INTO `mqc_library_outcome_dict` (`id_mqc_library_outcome`, `short_desc`, `long_desc`, `iscurrent`, `isvisible`) VALUES (5, 'Undecided', 'Library has no outcome', 1, 1) ON DUPLICATE KEY UPDATE iscurrent=1; 
INSERT INTO `mqc_library_outcome_dict` (`id_mqc_library_outcome`, `short_desc`, `long_desc`, `iscurrent`, `isvisible`) VALUES (6, 'Undecided final', 'Library has no outcome as final decision', 1, 1) ON DUPLICATE KEY UPDATE iscurrent=1; 
--
-- Updating fk constraints for ent and hist plex level library MQC
--
ALTER TABLE `mqc_library_outcome_ent` DROP FOREIGN KEY `fk_mqc_library_outcome_ent_mqc_outcome_dict1`;
ALTER TABLE `mqc_library_outcome_ent` ADD CONSTRAINT `fk_mqc_library_outcome_ent_mqc_library_outcome_dict1` FOREIGN KEY (`id_mqc_outcome`) REFERENCES `mqc_library_outcome_dict`(`id_mqc_library_outcome`) ON DELETE NO ACTION ON UPDATE NO ACTION;

ALTER TABLE `mqc_library_outcome_hist` DROP FOREIGN KEY `fk_mqc_library_outcome_ent_mqc_outcome_dict10`;
ALTER TABLE `mqc_library_outcome_hist` ADD CONSTRAINT `fk_mqc_library_outcome_hist_mqc_library_outcome_dict1` FOREIGN KEY (`id_mqc_outcome`) REFERENCES `mqc_library_outcome_dict`(`id_mqc_library_outcome`) ON DELETE NO ACTION ON UPDATE NO ACTION;
--
--
--
GRANT SELECT ON `mqc_library_outcome_dict` TO nqcro;
--
-- Updating plex level library qc to new undecided final outcome where lanes have
-- been rejected final.
--
START TRANSACTION;

UPDATE mqc_outcome_ent, mqc_library_outcome_ent
  SET mqc_library_outcome_ent.id_mqc_outcome = 6 -- Undecided final
  WHERE mqc_outcome_ent.id_mqc_outcome = 4 -- Rejected final
  AND mqc_outcome_ent.id_run = mqc_library_outcome_ent.id_run
  AND mqc_outcome_ent.position = mqc_library_outcome_ent.position
  AND mqc_library_outcome_ent.id_mqc_outcome = 5 -- Undecided
;

SHOW WARNINGS;

INSERT INTO mqc_library_outcome_hist (id_run, position, tag_index, id_mqc_outcome, username, modified_by)
  SELECT 
      entity.id_run,
      entity.position,
      entity.tag_index,
      entity.id_mqc_outcome,
      entity.username,
      entity.modified_by
    FROM mqc_library_outcome_ent entity
    WHERE entity.id_mqc_outcome = 6
    ORDER BY 
      entity.id_mqc_library_outcome_ent,
      entity.id_run,
      entity.position,
      entity.tag_index;

SHOW WARNINGS;

COMMIT;


