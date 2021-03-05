namespace :team do
  desc "Backfill country field"
  task backfill_country: :environment do
    Team.all.each do |team|
      team.update(country: team_to_country[team.name])
    end

    Investigation.includes(:creator_team).all.each do |investigation|
      investigation.update(notifying_country: investigation.creator_team.country)
    end

    def team_to_country
      {
        "Aberdeen City Council" => "Scotland",
        "Aberdeenshire Council" => "Scotland",
        "Angus Council" => "Scotland",
        "Antrim & Newtownabbey Council" => "Northern Ireland",
        "Ards and North Down Borough Council" =>	"Northern Ireland",
        "Argyll and Bute Council" => "Scotland",
        "Armagh, Banbridge and Craigavon Council" =>	"Northern Ireland",
        "Barking and Dagenham Borough" =>	"England",
        "Barnsley Metropolitan Council" =>	"England",
        "Bath and North East Somerset Council" =>	"England",
        "Bedford Borough Council" =>	"England",
        "Belfast City Council" =>	"Northern Ireland",
        "Birmingham City Council" =>	"England",
        "Blackburn with Darwen Borough Council" =>	"England",
        "Blackpool Borough Council" =>	"England",
        "Blaenau Gwent and Torfaen County Borough Council" =>	"Wales",
        "Bolton Metropolitan Borough Council" =>	"England",
        "Bournemouth, Christchurch and Poole Councils" =>	"England",
        "Bracknell Forest, West Berkshire and Wokingham Councils" => "England",
        "Bridgend, Cardiff and the Vale of Glamorgan" =>	"Wales",
        "Brighton & Hove City Council" =>	"England",
        "Bristol City Council" =>	"England",
        "Buckinghamshire & Surrey Councils" =>	"England",
        "Bury Metropolitan Borough Council" =>	"England",
        "Caerphilly County Borough Council" =>	"Wales",
        "Cambridgeshire County Council" =>	"England",
        "Carmarthenshire County Council" =>	"Wales",
        "Causeway Coast and Glens Council" =>	"Northern Ireland",
        "Central Bedfordshire Council" =>	"England",
        "Ceredigion County Council" =>	"Wales",
        "Cheshire East Council" =>	"England",
        "Cheshire West and Chester Council" =>	"England",
        "City of Edinburgh Council" => "Scotland",
        "City of London" =>	"England",
        "City of Stoke on Trent" => "England",
        "City of Westminster" => "England",
        "City of York" => "England",
        "Comhairle Nan Eilean Siar" => "Scotland",
        "Conwy County Borough Council" =>	"Wales",
        "Cornwall County Council" =>	"England",
        "Coventry City Council" =>	"England",
        "Cumbria County Council" =>	"England",
        "Darlington Borough Council" =>	"England",
        "Denbighshire County Council" =>	"Wales",
        "Derby City Council" =>	"England",
        "Derbyshire County Council" =>	"England",
        "Derry City and Strabane Council" =>	"Northern Ireland",
        "Devon, Somerset and Torbay Councils" =>	"England",
        "Doncaster Metropolitan Council" =>	"England",
        "Dorset County Council" =>	"England",
        "Driving Vehicle Standards Agency" =>	"United Kingdom",
        "Dudley Metropolitan Borough Council" =>	"England",
        "Dumfries and Galloway Council" => "Scotland",
        "Dundee City Council" =>	"Scotland",
        "Durham County Council" =>	"England",
        "East Ayrshire Council" =>	"Scotland",
        "East Dunbartonshire Council" =>	"Scotland",
        "East Lothian Council" =>	"Scotland",
        "East Renfrewshire Council" =>	"Scotland",
        "East Riding of Yorkshire Council" =>	"England",
        "East Sussex County Council" =>	"England",
        "Essex County Council" =>	"England",
        "Falkirk Council" =>	"Scotland",
        "Fermanagh and Omagh Council" => "Northern Ireland",
        "Fife Council" =>	"Scotland",
        "Flintshire County Council" =>	"Wales",
        "Gateshead Metropolitan Borough Council" =>	"England",
        "Glasgow City Council" =>	"Scotland",
        "Gloucestershire County Council" =>	"England",
        "Gwynedd County Council" =>	"Wales",
        "HSE Northern Ireland" => "Northern Ireland",
        "HSE chemical regulations division" => "Great Britain",
        "HSE civil explosives" => "Great Britain",
        "HSE product safety and construction" => "Great Britain",
        "HSE safety unit" => "Great Britain",
        "Halton Borough Council" =>	"England",
        "Hammersmith & Fulham Borough" =>	"England",
        "Hampshire County Council" =>	"England",
        "Hartlepool Borough Council" =>	"England",
        "Herefordshire Council" =>	"England",
        "Hertfordshire County Council" =>	"England",
        "Highland Council" =>	"Scotland",
        "Hull City Council" =>	"England",
        "Inverclyde Council" =>	"Scotland",
        "Isle of Anglesey County Council" =>	"Wales",
        "Isle of Wight Council" =>	"England",
        "Kent County Council" =>	"England",
        "Knowsley Metropolitan Borough Council" =>	"England",
        "Lancashire County Council" =>	"England",
        "Leicester City Council" =>	"England",
        "Leicestershire County Council" =>	"England",
        "Lincolnshire County Council" =>	"England",
        "Lisburn & Castlereagh City Council" =>	"Northern Ireland",
        "Liverpool City Council" =>	"England",
        "London Borough of Barnet" =>	"England",
        "London Borough of Bexley" => "England",
        "London Borough of Brent" => "England",
        "London Borough of Bromley" => "England",
        "London Borough of Camden" => "England",
        "London Borough of Croydon" => "England",
        "London Borough of Ealing" => "England",
        "London Borough of Enfield" => "England",
        "London Borough of Hackney" => "England",
        "London Borough of Haringey" => "England",
        "London Borough of Havering" => "England",
        "London Borough of Hillingdon" => "England",
        "London Borough of Hounslow" => "England",
        "London Borough of Islington" => "England",
        "London Borough of Lambeth" => "England",
        "London Borough of Lewisham" => "England",
        "London Borough of Newham" => "England",
        "London Borough of Redbridge" => "England",
        "London Borough of Southwark" => "England",
        "London Borough of Sutton" => "England",
        "London Borough of Tower Hamlets" => "England",
        "London Borough of Waltham Forest" => "England",
        "London Economics" => "England",
        "Luton Borough Council" =>	"England",
        "MHRA Medicine Borderline Section" =>	"United Kingdom",
        "Manchester City Council" =>	"England",
        "Medicines and Healthcare Products Regulatory Agency" =>	"United Kingdom",
        "Medway Council" =>	"England",
        "Merthyr Tydfil County Borough Council" =>	"Wales",
        "Mid & East Antrim Borough Council" =>	"Northern Ireland",
        "Mid Ulster District Council" =>	"Northern Ireland",
        "Middlesbrough Borough Council" =>	"England",
        "Midlothian Council" =>	"Scotland",
        "Milton Keynes Council" =>	"England",
        "Monmouthshire County Council" =>	"Wales",
        "Moray Council" =>	"Scotland",
        "Neath Port Talbot County Borough Council" =>	"Wales",
        "Newcastle upon Tyne City Council" =>	"England",
        "Newport City Council" =>	"Wales",
        "Newry, Mourne and Down Council" =>	"Northern Ireland",
        "Norfolk County Council" =>	"England",
        "North Ayrshire Council" =>	"Scotland",
        "North East Lincolnshire Council" =>	"England",
        "North Lanarkshire Council" =>	"Scotland",
        "North Lincolnshire Council" =>	"England",
        "North Somerset Council" =>	"England",
        "North Tyneside Council" =>	"England",
        "North Yorkshire County Council" =>	"England",
        "Northamptonshire County Council" =>	"England",
        "Northumberland County Council" =>	"England",
        "Nottingham City Council" =>	"England",
        "Nottinghamshire County Council" =>	"England",
        "OPSS Analysis" =>	"United Kingdom",
        "OPSS Behavioural Insights" =>	"United Kingdom",
        "OPSS Compliance & Testing" =>	"United Kingdom",
        "OPSS Connections" =>	"United Kingdom",
        "OPSS Digital" =>	"United Kingdom",
        "OPSS Ecodesign" =>	"United Kingdom",
        "OPSS Enforcement" =>	"United Kingdom",
        "OPSS Engineering & Technology" =>	"United Kingdom",
        "OPSS Incident Management" =>	"United Kingdom",
        "OPSS Intelligence" =>	"United Kingdom",
        "OPSS Legal" =>	"United Kingdom",
        "OPSS Operational support unit" =>	"United Kingdom",
        "OPSS PPE business liason" =>	"United Kingdom",
        "OPSS Policy" =>	"United Kingdom",
        "OPSS Ports and Borders" =>	"United Kingdom",
        "OPSS Product Safety Enforcement" =>	"United Kingdom",
        "OPSS SPOC" =>	"United Kingdom",
        "OPSS Science" =>	"United Kingdom",
        "OPSS Stakeholder Engagement" =>	"United Kingdom",
        "OPSS Trading Standards Co-ordination" =>	"United Kingdom",
        "Ofcom" =>	"United Kingdom",
        "Oldham Metropolitan Borough Council" => "England",
        "Orkney Islands Council" =>	"Scotland",
        "Oxfordshire County Council" =>	"England",
        "Pembrokeshire County Council" =>	"Wales",
        "Perth and Kinross Council" =>	"Scotland",
        "Plymouth City Council" =>	"England",
        "Portsmouth City Council" =>	"England",
        "Powys County Council" =>	"Wales",
        "Reading Borough Council" =>	"England",
        "Redcar & Cleveland Borough Council" =>	"England",
        "Renfrewshire Council" =>	"Scotland",
        "Rhondda Cynon Taf County Borough Council" =>	"Wales",
        "Richmond, Merton and Wandsworth Borough" =>	"England",
        "Rochdale Metropolitan Borough Council" =>	"England",
        "Rotherham Council" =>	"England",
        "Royal Borough of Greenwich" =>	"England",
        "Royal Borough of Kensington and Chelsea" =>	"England",
        "Royal Borough of Kingston upon Thames" =>	"England",
        "Royal Borough of Windsor and Maidenhead Council" =>	"England",
        "Salford City Council" =>	"England",
        "Sandwell Metropolitan Borough Council" =>	"England",
        "Scottish Borders Council" =>	"Scotland",
        "Sefton Metropolitan Borough Council" =>	"England",
        "Sheffield City Council" =>	"England",
        "Shetland Islands Council" =>	"Scotland",
        "Shropshire County Council" =>	"England",
        "Slough Borough Council" =>	"England",
        "Solihull Metropolitan Borough Council" =>	"England",
        "South Ayrshire Council" =>	"Scotland",
        "South Gloucestershire Council" =>	"England",
        "South Lanarkshire Council" =>	"Scotland",
        "South Tyneside Metropolitan Borough Council" =>	"England",
        "Southampton City Council" =>	"England",
        "Southend-on-Sea Borough Council" =>	"England",
        "St Helens Metropolitan Borough Council" =>	"England",
        "Staffordshire County Council" =>	"England",
        "Stirling & Clackmannanshire Councils" =>	"Scotland",
        "Stockport Council" =>	"England",
        "Stockton-on-Tees Borough Council" =>	"England",
        "Suffolk County Council" =>	"England",
        "Sunderland City Council" =>	"England",
        "Swansea City and County Council" =>	"Wales",
        "Swindon Borough Council" =>	"England",
        "Tameside Council" =>	"England",
        "Telford & Wrekin Council" =>	"England",
        "Thurrock  Council" =>	"England",
        "Trafford Metropolitan Borough Council" =>	"England",
        "Walsall Metropolitan Borough Council" =>	"England",
        "Warrington Borough Council" =>	"England",
        "Warwickshire county Council" =>	"England",
        "West Dunbartonshire Council" =>	"Scotland",
        "West Lothian Council" =>	"Scotland",
        "West Sussex County Council" =>	"England",
        "West Yorkshire Joint Services" =>	"England",
        "Wigan Metropolitan Borough Council" =>	"England",
        "Wiltshire County Council" =>	"England",
        "Wirral Borough Council" =>	"England",
        "Wolverhampton City Council" =>	"England",
        "Worcestershire County Council" =>	"England",
        "Wrexham County Borough Council" =>	"Wales"
      }
    end
  end
end
