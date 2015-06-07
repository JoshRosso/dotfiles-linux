call XmlAddDoctypeSystemDef(
        \ "http://www.oasis-open.org/docbook/xml/4.3/docbookx.dtd",
	\ "docbook-4.3")
call XmlAddDoctypeSystemDef(
        \ "http://www.oasis-open.org/docbook/xml/4.4/docbookx.dtd",
	\ "docbook-4.4")
call XmlAddDoctypePublicDef("-//OASIS//DTD DocBook XML V4.3//EN",
	\ "docbook-4.3")
call XmlAddDoctypePublicDef("-//OASIS//DTD DocBook XML V4.4//EN",
	\ "docbook-4.4")
