import type { TagsConfig } from './types';
import { info } from './logger';

interface TaggableResource {
  freeformTags?: Record<string, string>;
  definedTags?: Record<string, Record<string, string>>;
}

function parseTagList(tagString: string): Array<{ key: string; value?: string }> {
  if (!tagString || tagString.trim() === '') return [];
  return tagString.split(',').map((pair) => {
    const [key, value] = pair.trim().split('=');
    return { key: key?.trim(), value: value?.trim() };
  }).filter((t) => t.key);
}

function resourceHasTag(resource: TaggableResource, tag: { key: string; value?: string }): boolean {
  const freeformTags = resource.freeformTags || {};
  if (tag.value !== undefined) {
    return freeformTags[tag.key] === tag.value;
  }
  return tag.key in freeformTags;
}

export function shouldIncludeResource(
  resource: TaggableResource,
  tagsConfig: TagsConfig,
): boolean {
  // mustHaveTags: ALL tags must be present
  const mustHaveTags = parseTagList(tagsConfig.mustHaveTags);
  if (mustHaveTags.length > 0) {
    const allPresent = mustHaveTags.every((tag) => resourceHasTag(resource, tag));
    if (!allPresent) return false;
  }

  // anyInListTags: at least ONE tag must be present
  const anyInListTags = parseTagList(tagsConfig.anyInListTags);
  if (anyInListTags.length > 0) {
    const anyPresent = anyInListTags.some((tag) => resourceHasTag(resource, tag));
    if (!anyPresent) return false;
  }

  // noneInTheList: if ANY tag matches, exclude
  const noneInTheList = parseTagList(tagsConfig.noneInTheList);
  if (noneInTheList.length > 0) {
    const anyMatches = noneInTheList.some((tag) => resourceHasTag(resource, tag));
    if (anyMatches) return false;
  }

  return true;
}

export function shouldIncludeVolume(
  volume: TaggableResource,
  tagsConfig: TagsConfig,
): boolean {
  const noneOnVolume = parseTagList(tagsConfig.noneOnVolume);
  if (noneOnVolume.length === 0) return true;

  const anyMatches = noneOnVolume.some((tag) => resourceHasTag(volume, tag));
  return !anyMatches;
}

export function filterResources<T extends TaggableResource>(
  resources: T[],
  tagsConfig: TagsConfig,
): T[] {
  const filtered = resources.filter((r) => shouldIncludeResource(r, tagsConfig));
  info('Tag filter applied', {
    total: resources.length,
    included: filtered.length,
    excluded: resources.length - filtered.length,
  });
  return filtered;
}
