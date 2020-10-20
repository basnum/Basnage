<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="3.0" xmlns="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:lr="http://www.tagsandmore.fr"
    xpath-default-namespace="http://www.tei-c.org/ns/1.0" expand-text="yes" exclude-result-prefixes="#all">
    <xsl:output method="xml" indent="yes"/>
    <!-- En XSLT 3.0  permet une  copie à l'identique de ce qui n'est pas transformé -->
    <xsl:mode on-no-match="shallow-copy"/>
    <xsl:variable name="usgPrefixes"
        select='("Terme des", "Terme de", "Terme d&apos;", "en termes des", "en termes de", "en termes d&apos;", "En  termes de", "En  termes d&apos;")'/>
    <!-- Template permettant d'ajouter automatiquement un @xml:id s'il n'y en a pas -->
    <!-- +++++++ Ne doit-on pas tout simplement crasher tous les xml:id existants pour garantir la cohérence? Risque de perte de liens? -->
    <xsl:template match="entry[not(@xml:id)]">
        <!-- On copie le noeud à l'identique sauf qu'on lui ajoute @xml:id -->
        <xsl:copy>
            <xsl:attribute name="xml:id">
                <xsl:choose>
                    <xsl:when test="form[@type = 'lemmaGrp']">
                        <xsl:choose>
                            <xsl:when test="form[@type = 'lemmaGrp'][1]/form[@type = 'lemma'][1]">
                                <xsl:value-of
                                    select="lower-case(form[@type = 'lemmaGrp'][1]/form[@type = 'lemma'][1]/orth[1])"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:message>Pas de "form" trouvé! (dans un "lemmaGrp")</xsl:message>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:when test="form[@type = 'lemma']">
                        <xsl:value-of select="lower-case(form[@type = 'lemma'][1]/orth[1])"/>
                    </xsl:when>
                    <!--<xsl:otherwise>
                        <xsl:message>Pas de "form" trouvé! (dans un "lemma")</xsl:message>
                    </xsl:otherwise>-->
                </xsl:choose>
            </xsl:attribute>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
     

    <!-- Nettoyage des variantes commençant par "ou  plutôt" ou "ou" pour mettre le texte ccorrespondant  dans un <lbl>-->
    <xsl:template match="form[@type = 'variant']/orth[starts-with(., 'ou')]">
        <xsl:choose>
            <xsl:when test="starts-with(., 'ou plutôt')">
                <!--<xsl:message>Commence par 'ou plutôt': {.}</xsl:message>-->
                <lbl>ou plutôt</lbl>
                <xsl:copy>
                    <xsl:value-of select="substring-after(., 'ou plutôt') => normalize-space()"/>
                </xsl:copy>
            </xsl:when>
            <xsl:otherwise>
                <!--<xsl:message>Commence par 'ou': {.}</xsl:message>-->
                <lbl>ou</lbl>
                <xsl:copy>
                    <xsl:value-of select="substring-after(., 'ou') => normalize-space()"/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- Ajout de @target sur les <ref> -->
    <!-- Deux tests sont nécessaire: -->
    <!-- 1. vérifier qu'on n'a pas déjà un @target pour ne pas écraser -->
    <!-- Vérifier que ref/@type est bien 'entry' ===> à implémenter en production pour que ça s'applique -->

    <!-- +++++++ Ne doit-on pas tout simplement crasher tous les @target existants pour garantir la cohérence? Risque de perte de liens? -->
    <!-- +++++++ Doit-on vérifier l'existance d'une entrée, ou on fait un test a posteriori (préférable à mon gout) ? -->
    <xsl:template match="xr/ref[not(@target)]">
        <xsl:copy>
            <xsl:attribute name="target" select="concat('#', lower-case(.))"/>
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>
    
    <!-- Ont raite les <xr> non struturés, qui commencent par Voyez, suivi d'un seul token -->
    <!-- et suivi d'un <pc>.</pc> -->
    <xsl:template match="xr[not(*) and starts-with(.,'Voyez') and following::*[1][name() = 'pc' and . = '.']]">
        <xsl:copy>
            <xsl:apply-templates select="@*"/>
            <lbl>Voyez</lbl>
            <ref>{substring-after(.,"Voyez") => normalize-space()}</ref>
            <pc>.</pc>
        </xsl:copy>
        <xsl:message>Voyez: {substring-after(.,"Voyez") => normalize-space()}</xsl:message>
    </xsl:template>

    <!-- Ajout d'un attribut @type sur <usg> quand celui-ci n'existe pas et qu'on sait détecter une expression caractéristique -->
    <!-- +++++++ Identifier tous les prefixes possibles cf. $usgPrefixes -->
    <xsl:template match="usg[not(@type)]">
        <xsl:variable name="usgContent" select="." as="xs:string"/>
        <xsl:variable name="foundUsgPrefix"
            select="
                filter($usgPrefixes, function ($x) {
                    starts-with($usgContent, $x)
                })"/>
        <xsl:choose>
            <xsl:when test="count($foundUsgPrefix) != 0">
                <xsl:variable name="theAnaSource">#{substring-after($usgContent,$foundUsgPrefix[1]) => normalize-space()
                    => lower-case() => translate("$","s")}</xsl:variable>
                <xsl:variable name="theAna">{replace($theAnaSource,"- ","") => replace("(,? &amp; (d'|de) )","#")}</xsl:variable>
                <!--   -->
                <xsl:copy>
                    <xsl:attribute name="type" select="'domain'"/>
                    <xsl:attribute name="ana" select="$theAna"/>
                    <xsl:apply-templates/>
                </xsl:copy>
            </xsl:when>
            <!--<xsl:otherwise><xsl:message>On n'a pas su interpréter un usage pour: {.} => {$foundUsgPrefix}</xsl:message></xsl:otherwise>-->
        </xsl:choose>
    </xsl:template>

    <!-- Fusion des informations grammaticales avec d'éventuels points d'abbréviation -->
    <!-- variable contenant d'éventuel préfixes à isoler dans un <lbl> avant le <pos> -->
    <xsl:variable name="prefixesPOS"
        select='("&amp; par fois ", "&amp; plus $ouvent ", "&amp; plus souvent "
        , "&amp; quelquefois au$$i "  , "&amp; quelquefois aussi ", "&amp; queiquefois ", "&amp; quelquefois ", "&amp; ")'/>
    <!-- On n'agit que si le <pos> est dans la liste des abbréviés et est immédiatement suivi d'un <pc>.</pc> -->
    <xsl:template match="gramGrp/pos[lr:isAbbreviatedPOS(.) and following::*[1][name() = 'pc' and . = '.']]">
        <xsl:copy>{. || "."}</xsl:copy>
        <xsl:message>On merge un pos: {. || "."}</xsl:message>        
    </xsl:template>

    <xsl:function name="lr:isAbbreviatedPOS" as="xs:boolean">
        <xsl:param name="thePOSString" as="xs:string"/>
        <xsl:variable name="abbreviatedPOS" 
            select='("adject", "adjet", "adj",  
            "adverb", "adv", "adu", "odv",
            "conj", "Conj", "con",
            "particip", "part",
            "$ubft", "$ub$t", "subst", "Subst", "s", "$", "v", "verb")'/>
        <xsl:sequence
            select="
                count(filter($abbreviatedPOS, function ($x) {
                    $thePOSString = $x
                })) != 0"/>
    </xsl:function>
    
    <!-- On n'agit que si le <gen> est dans la liste des abbréviés et est immédiatement suivi d'un <pc>.</pc> -->
    <xsl:template match="gramGrp/gen[lr:isAbbreviatedGEN(.) and following::*[1][name() = 'pc' and . = '.']]">
        <xsl:copy>{. || "."}</xsl:copy>
        <xsl:message>On merge un gen: {. || "."}</xsl:message>        
    </xsl:template>
    
    <xsl:function name="lr:isAbbreviatedGEN" as="xs:boolean">
        <xsl:param name="thePOSString" as="xs:string"/>
        <xsl:variable name="abbreviatedGEN" select='("f", "fem", "m", "masc")'/>
        <xsl:sequence
            select="
            count(filter($abbreviatedGEN, function ($x) {
            $thePOSString = $x
            })) != 0"/>
    </xsl:function>
    
    <!-- On n'agit que si le <number> est dans la liste des abbréviés et est immédiatement suivi d'un <pc>.</pc> -->
    <xsl:template match="gramGrp/number[lr:isAbbreviatedNUMBER(.) and following::*[1][name() = 'pc' and . = '.']]">
        <xsl:copy>{. || "."}</xsl:copy>
        <xsl:message>On merge un number: {. || "."}</xsl:message>        
    </xsl:template>
    
    
    <xsl:function name="lr:isAbbreviatedNUMBER" as="xs:boolean">
        <xsl:param name="theNUMBERString" as="xs:string"/>
        <xsl:variable name="abbreviatedNUMBER" select='("plur")'/>
        <xsl:sequence
            select="
            count(filter($abbreviatedNUMBER, function ($x) {
            $theNUMBERString = $x
            })) != 0"/>
    </xsl:function>
    
    <!-- Et maintenant le recollage des <def> avec le point qui suit. -->
    
    <xsl:template match="def[not(ends-with(.,'.')) and following::*[1][name() = 'pc' and . = '.']]">
        <xsl:copy>
            <xsl:apply-templates/>
            <pc>.</pc>
        </xsl:copy>
        <xsl:message>On merge un def: {. || "."}</xsl:message>        
    </xsl:template>
    
    <!-- Règle générique qui supprime les <pc> consommés ailleurs --><!-- On crée la règle duale qui va anihiler le <pc> -->
    <xsl:template match="pc">
        <xsl:choose>
            <xsl:when test="preceding::*[1][name() = 'def' and not(ends-with(.,'.'))]"/>
            <xsl:when test="preceding::*[1][name() = 'pos' and lr:isAbbreviatedPOS(.)]"/>
            <xsl:when test="preceding::*[1][name() = 'gen' and lr:isAbbreviatedGEN(.)]"/>
            <xsl:when test="preceding::*[1][name() = 'number' and lr:isAbbreviatedNUMBER(.)]"/>
            <xsl:when test="preceding::*[1][name() = 'xr' and not(*) and starts-with(.,'Voyez')]"/>
            <xsl:otherwise>
                <xsl:copy>
                    <xsl:apply-templates/>
                </xsl:copy>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    
    <!-- Règle gébérique qui transforme en <lbl> les éléments grammaticaux qui ne contiennent que & -->
    <xsl:template match="gramGrp/*[.='&amp;' and (name()='gen' or name()='number' or name()='subc')]">
        <lbl>
            <xsl:apply-templates/>
        </lbl>
    </xsl:template>
    
    <!-- On traite les <form> qu in'ont pas  de <orth> (ni de <form> en cas de récursivité) dans des <sense> -->
    
    <xsl:template match="sense/form[not(orth) and not(form)]">
        <xsl:copy>
            <orth>
                <xsl:apply-templates/>
            </orth>
        </xsl:copy>
    </xsl:template>
    
    <!-- On numérote les <sense> -->
    <xsl:template match="sense">
        <!-- On copie l'élément (y compris des attributs existant) -->
        <xsl:copy>
            <!-- On ne numérote que si le <sense> n'est pas tout seul dans sa fratrie -->
            <xsl:if test="count(../sense) > 1">
                <xsl:attribute name="n" select="count(preceding-sibling::sense) + 1"/>
            </xsl:if>
            <!-- On parcours le contenu pour l'intégrer -->
            <xsl:apply-templates/>
        </xsl:copy>
    </xsl:template>

</xsl:stylesheet>
