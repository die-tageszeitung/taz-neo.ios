function checkPassword(password, mail=null) {

	if(password.length < 12) {
		return {
			valid:  false,
			message: "Passwort ist zu kurz",
			level: 0,
			color: "#ccc"
		};
	}
	
	var mailprefix = mail.length > 0 && mail.includes("@") ? mail.split("@")[0] : null
	
	if(mailprefix && password.includes(mailprefix)){
			return {
			valid:  false,
			message: "Ihr Passwort darf nicht Teile Ihrer E-Mail enthalten!",
			level: 0,
			color: "#ccc"
		};
	}
  
	var color = "#ccc"
	var level = 0
  
	if(/\d/.test(password)){
		level += 1
	}

	if(password !== password.toLowerCase()){
		level += 1
	}
	
	if(password !== password.toUpperCase()){
		level += 1
	}
	
	if(/[ `!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?~]/.test(password)){
		level += 1
	}
	
	if(password.length > 15) {
		level += 1
	}
	
	switch (level) {
  		case 0: case 1:
  			return {valid:  true, message: "Das geht noch besser!", level: 1, color: "#f00"};
  		case 2: case 3:
  			return {valid:  true, message: "Du bist auf dem richtigen Weg!", level: 2, color: "#fb0"};
	  default:
		  return {valid:  true, message: "Das sieht gut aus!", level: 3, color: "#0f0"};
	}
}