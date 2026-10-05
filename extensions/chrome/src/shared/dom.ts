type ElementConstructor<T extends HTMLElement> = abstract new (...args: never[]) => T;

export function requiredElement<T extends HTMLElement>(
  id: string,
  constructor: ElementConstructor<T>,
  surface: string
): T {
  const element = document.getElementById(id);
  if (!(element instanceof constructor)) {
    throw new Error(`Missing required ${surface} element: ${id}`);
  }

  return element;
}
