CREATE TABLE `hotel_rooms` (
  `identifier` varchar(80) NOT NULL,
  `expiration` int(11) NOT NULL,
  `safe` text NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `hotel_rooms`
  ADD PRIMARY KEY (`identifier`);
COMMIT;
