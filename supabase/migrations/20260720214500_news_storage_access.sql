begin;

grant execute on function private.can_access_news_object(text)
to authenticated;

commit;
