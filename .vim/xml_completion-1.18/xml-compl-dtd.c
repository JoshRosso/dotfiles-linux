/****************************************************************/
/*
 * File: xml-compl-dtd.c
 * Author: David Tardon
 * Created: 25.04.2005 19:32
 * Modified: 09.01.2006 16:00
 * Description: Z DTD vytvori definicni soubor(y) pro vim
 * xml_completion.
 */
/****************************************************************/


#include <string.h>
#include <stdio.h>
#include <libxml/tree.h>


xmlChar* eArray[2000][2]; /* Pole elementu */
int eIndex = 0; /* Index nove pridavaneho elementu */
xmlHashTablePtr ns_table;  // Tabulka mapovani prefixu NS na URI


void eFun(void * payload, void * data, xmlChar * name) {
  eArray[eIndex][0] = xmlStrdup(name);
  eArray[eIndex++][1] = xmlStrdup(((xmlElementPtr) payload)->prefix);
}


/*
 * Prevede prefix na jemu odpovidajici URI.
 * Podle zadaneho typu rozhoduje, co delat, je-li prefix prazdny.
 */
xmlChar* prefix_to_uri(const xmlChar* prefix, xmlElementType type) {
  xmlChar* uri = 0;
  if (prefix != NULL) {
    uri = xmlStrcat(xmlStrdup("xmlns:"), prefix);
  } else {
    if (type == XML_ELEMENT_NODE) {
      uri = xmlStrdup("xmlns");
    } else if (type == XML_ATTRIBUTE_NODE) {
      uri = xmlStrdup("");
    }
  }
  uri = (xmlChar*) xmlHashLookup(ns_table, uri);
  return (uri == NULL) ? xmlStrdup("") : uri;
}

void
print_element_standalone(const xmlElementPtr element) {
  printf("%s::\n", element->name);
}


void
print_values(
    const xmlElementPtr element,
    const xmlAttributePtr attribute)
{
  xmlEnumerationPtr value = attribute->tree;
  do {
     printf("%s:{%s}%s:%s\n", element->name,
	prefix_to_uri(attribute->prefix, XML_ATTRIBUTE_NODE),
	attribute->name, value->name);
    value = value->next;
  } while (value != NULL);
}


void
print_attributes(const xmlElementPtr element) {
  xmlAttributePtr att = (xmlAttributePtr) element->attributes;
  do {
    if (att->atype == XML_ATTRIBUTE_ENUMERATION) {
      /* Zpracovani vyctu do seznamu moznych hodnot */
      print_values(element, att);
    } else {
      printf("%s:{%s}%s:\n", element->name,
	  prefix_to_uri(att->prefix, XML_ATTRIBUTE_NODE),
	  att->name);
    }
    att = att->nexth;
  } while (att != NULL);
}


void print_subelement(const xmlElementPtr base,
    const xmlElementContentPtr child)
{
  switch (child->type) {
  case XML_ELEMENT_CONTENT_PCDATA :
    break;
  case XML_ELEMENT_CONTENT_ELEMENT :
    printf("%s/{%s}%s\n", base->name,
	prefix_to_uri(child->prefix, XML_ELEMENT_NODE),
	child->name);
    break;
  case XML_ELEMENT_CONTENT_OR :
  case XML_ELEMENT_CONTENT_SEQ :
    print_subelement(base, child->c1);
    print_subelement(base, child->c2);
    break;
  default :
    printf("##default\n");
  }
}

void print_subelements(const xmlElementPtr element) {
  switch (element->etype) {
  case XML_ELEMENT_TYPE_MIXED :
  case XML_ELEMENT_TYPE_ELEMENT :
    print_subelement(element, element->content);
  case XML_ELEMENT_TYPE_ANY :
    /* printf("ANY\n"); */
    break;
  case XML_ELEMENT_TYPE_EMPTY :
    /* printf("EMPTY\n"); */
    break;
  }
}


void usage() {
  printf("xml-compl-dtd <dtdfile> uri_mapping+\n\tdtdfile\t\t");
  printf("jmeno DTD ");
  printf("souboru\n\turi_mapping\t\tmapovani prefixu ns na URI\n");
  printf("Program zapisuje na stdout.");
}


int main(int argc, char ** argv)
{
  char * dtdfile = argv[1];
  xmlDtdPtr dtd;
  int i = 2;
  const char* xml_prefix_ns[] = {
    "xml", "Xml", "XMl", "xMl", "xML", "xmL", "XmL", "XML"
  };

  ns_table = xmlHashCreate(32);
  int j = 0;
  for (; j < 8; ++j) {
    xmlHashAddEntry(  // URI pro prefix xml
      ns_table,
      xmlStrdup(xml_prefix_ns[j]),
      xmlStrdup("http://www.w3.org/XML/namespace")
    );
  }

  for (; i < argc; ++i) {
    char uri_buf[256];
    char prefix_buf[256];
    xmlChar* uri = 0;
    xmlChar* prefix = 0;

    memset(uri_buf, 0, 256);
    memset(prefix_buf, 0, 256);
    char* delim = strchr(argv[i], '=');
    strncpy(prefix_buf, argv[i], delim - argv[i]);
    strncpy(uri_buf, delim + 1, strlen(argv[i]) - (delim - argv[i]) - 1);
    uri = xmlCharStrdup(uri_buf);
    prefix = xmlCharStrdup(prefix_buf);
    if (xmlHashAddEntry(ns_table, prefix, uri) == -1) {
      fprintf(stderr, "%s: %d: hash add error\n",__FILE__, __LINE__);
    }
    /* printf("ns_table['%s'] = '%s'\n", prefix, xmlHashLookup(ns_table, prefix)); */
  }

  dtd = xmlParseDTD(NULL, dtdfile); /* Ziskani DTD */

  xmlHashScan((xmlElementTablePtr) dtd->elements,
      (xmlHashScanner) eFun, NULL);
  for (i = 0; i < eIndex; i++) {
    xmlElementPtr el = (xmlElementPtr) xmlHashLookup2(
	dtd->elements, eArray[i][0], eArray[i][1]
    );
    if (el->attributes != NULL) {
      print_attributes(el);
    } else {
      print_element_standalone(el);
    }
    print_subelements(el);
  }

  return 0;
}
