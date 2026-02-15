User - Either the app owner, or someone the app owner wants represented in the app.

LeaguePlayer - A representation of a User in a League. A User can be a participant in multiple Leagues and they should have a single LeaguePlayer per League they are involved in.

League - A collection of information regarding LeaguePlayers and their Matches against each other. A League should be parametrised by a particular subclass of Match.

RankingPolicy - When a League is set up, it needs to be given a RankingPolicy. This RankingPolicy will take a list of all matches and calculate the ranking of each LeaguePlayer based on their Match results. It will also calculate relevant metrics for each LeaguePlayer based on their Match results. The RankingPolicy will be parametrised by a particular subclass of Match.

Match – A competition between Sides. A Match is made up of two or more Sides playing against each other.

Side – A set of LeaguePlayers from the same League competing together against other Sides. A Side can be made up of one or more LeaguePlayers.