#!/usr/bin/env perl
# fetch quora data and put in sqlite DB
use strict;
use warnings;
use DBI;
use Mojo::DOM;
use Data::Dumper;
use IO::All;
use LWP::Simple;

#my $dbh = DBI->connect("dbi:SQLite:dbname=quora","","");
my $out = IO::All->new("output.txt");
my $base_url = "http://www.quora.com/sitemap/questions?page_id=2";
my $html = get($base_url);
my $dom = Mojo::DOM->new($html);

my $WANT_ANS_CUTOFF = 9;
my $ANS_COUNT_CUTOFF = 1;
my $UPVOTE_CUTOFF = 4;

# get the links from the sitemap
my @site_map_links = get_sitemap_page_links($dom);

foreach my $link (@site_map_links){

	my $html = get($link);

	my ($title, $q_text, $abstract, $want_ans, $ans_count, $ans_upvotes) = '';

	my $page = Mojo::DOM->new($html);
	
	$page->find('span.count')->each( sub{
		if($_->parent->text  && $_->parent->text eq "Want Answers"){
			$want_ans = $_->text if $_->text;
		}
	});
	
	next if $want_ans < $WANT_ANS_CUTOFF;

	$page->find('div.answer_count')->each( sub{
		if($_->text && $_->text =~ /(\d+)\sAnswers/){
			$ans_count = $1;	
		}
	});

	next if $ans_count < $ANS_COUNT_CUTOFF;

	# title for the page (short question text)
	$page->find('h1')->each( sub{
		$title = $_->text if $_->text;
	});

	# get the content of the question
	$page->find('div.question_details_text')->each( sub{
			$q_text = $_->text if $_->text;
	});


	# search inside top Answer
	$page->find('div.Answer')->each( sub{
		#get the abstract text	
		$_->find('div[id$=_container]')->each( sub{
			$abstract = $_->text if $_->text;
			last;
		});

		# get upvotes for this post
		$_->find('div.primary_item')->each( sub{
			$_->find('span.count')->each( sub{
				$ans_upvotes = $_->text if $_->text;
			});
		});

	});

	next if $ans_upvotes < $UPVOTE_CUTOFF;

	print_to_file($title, $q_text, $abstract);
}




# returns an array of links for a page on the sitemap
sub get_sitemap_page_links {
	my $page = shift;
	my @links = ();
	
	$page->find('a[href]')->each ( sub{
			
		if(my $remainder = $_->{href} =~ m/http:\/\/www\.quora\.com\/(.*?)/){
			next unless $remainder;
			next if $remainder  =~ m/(?:questions\?page_id=)|(?:#)/;
			push(@links, $_->{href});
		}
		
	});
	
	return @links;
}

# print doc to output file
sub print_to_file {
	my ($title, $q_text, $abstract) = @_;

	qq(<doc>
<field name="title"><![CDATA[$title]]></field>
<field name="title_match"><![CDATA[$title]]></field>
<field name="paragraph">$abstract</field>
<field name="source">quora"</field>
</doc>
) >> io($out);
}
